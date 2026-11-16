//! The XeFlash model container (`.xfm`).
//!
//! ```text
//! offset 0   "XFLASH01"
//! offset 8   u64 LE  header length in bytes
//! offset 16  JSON header
//! ...        blobs, each aligned to 4096 bytes (mmap / direct upload friendly)
//! ```
//!
//! The header lists tensors. A `matrix` tensor carries tile-ordered codes plus
//! f32 row and column scales and reconstructs as
//! `W[i][j] = row_scale[i] * (q[i][j] + 0.5) * col_scale[j]`.
//! A matrix may be the row-wise stack of several checkpoint tensors that share
//! their input (`parts`).
//! A `dense` tensor is the original data, untouched (bf16 norms, biases, ...).

use std::fs::File;
use std::io::{BufWriter, Seek, SeekFrom, Write};
use std::path::Path;

use memmap2::Mmap;
use serde_json::{Value, json};
use xeflash_core::{Error, Result, WeightFormat};

const MAGIC: &[u8; 8] = b"XFLASH01";
const ALIGN: u64 = 4096;

fn invalid(msg: impl Into<String>) -> Error {
    Error::Invalid(msg.into())
}

fn format_name(f: WeightFormat) -> &'static str {
    match f {
        WeightFormat::S4 => "s4",
        WeightFormat::S2 => "s2",
        WeightFormat::S8 => "s8",
        _ => "unsupported",
    }
}

fn format_from(name: &str) -> Result<WeightFormat> {
    match name {
        "s4" => Ok(WeightFormat::S4),
        "s2" => Ok(WeightFormat::S2),
        "s8" => Ok(WeightFormat::S8),
        other => Err(invalid(format!("unknown weight format {other} in container"))),
    }
}

/// Streaming writer: blobs are appended as they are produced; the header is
/// written last into space reserved at the front.
pub struct ContainerWriter {
    out: BufWriter<File>,
    pos: u64,
    header_reserve: u64,
    tensors: Vec<Value>,
    meta: Value,
}

impl ContainerWriter {
    /// `header_reserve` bytes are set aside for the JSON header (1 MiB is ample
    /// for this model).
    pub fn create(path: &Path, meta: Value, header_reserve: u64) -> Result<Self> {
        let mut out = BufWriter::with_capacity(8 << 20, File::create(path)?);
        let start = (16 + header_reserve).div_ceil(ALIGN) * ALIGN;
        out.seek(SeekFrom::Start(start))?;
        Ok(ContainerWriter { out, pos: start, header_reserve, tensors: Vec::new(), meta })
    }

    fn blob(&mut self, bytes: &[u8]) -> Result<Value> {
        let pad = (ALIGN - self.pos % ALIGN) % ALIGN;
        if pad != 0 {
            self.out.write_all(&vec![0u8; pad as usize])?;
            self.pos += pad;
        }
        let off = self.pos;
        self.out.write_all(bytes)?;
        self.pos += bytes.len() as u64;
        Ok(json!({ "off": off, "len": bytes.len() }))
    }

    #[allow(clippy::too_many_arguments)]
    pub fn add_matrix(
        &mut self,
        name: &str,
        format: WeightFormat,
        rows: usize,
        cols: usize,
        tiles: &[u8],
        row_scale: &[f32],
        col_scale: &[f32],
        sqnr_db: f64,
        parts: &[String],
    ) -> Result<()> {
        if row_scale.len() != rows || col_scale.len() != cols || tiles.len() != rows / 16 * (cols / 32) * format.tile_bytes() {
            return Err(invalid(format!("inconsistent sizes for matrix {name}")));
        }
        let w = self.blob(tiles)?;
        let rs = self.blob(&f32_bytes(row_scale))?;
        let cs = self.blob(&f32_bytes(col_scale))?;
        self.tensors.push(json!({
            "name": name, "kind": "matrix", "format": format_name(format),
            "rows": rows, "cols": cols, "w": w, "row_scale": rs, "col_scale": cs,
            "sqnr_db": (sqnr_db * 1000.0).round() / 1000.0,
            "parts": parts,
        }));
        Ok(())
    }

    pub fn add_dense(&mut self, name: &str, dtype: &str, shape: &[usize], bytes: &[u8]) -> Result<()> {
        let data = self.blob(bytes)?;
        self.tensors.push(json!({ "name": name, "kind": "dense", "dtype": dtype, "shape": shape, "data": data }));
        Ok(())
    }

    pub fn finish(mut self) -> Result<u64> {
        let header = serde_json::to_vec(&json!({ "meta": self.meta, "tensors": self.tensors }))
            .map_err(|e| invalid(format!("cannot serialise header: {e}")))?;
        if header.len() as u64 > self.header_reserve {
            return Err(invalid(format!(
                "header needs {} bytes but only {} were reserved",
                header.len(),
                self.header_reserve
            )));
        }
        self.out.seek(SeekFrom::Start(0))?;
        self.out.write_all(MAGIC)?;
        self.out.write_all(&(header.len() as u64).to_le_bytes())?;
        self.out.write_all(&header)?;
        self.out.flush()?;
        self.out.get_ref().sync_all()?;
        Ok(self.pos)
    }
}

fn f32_bytes(v: &[f32]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}

pub struct Matrix<'a> {
    pub name: &'a str,
    pub format: WeightFormat,
    pub rows: usize,
    pub cols: usize,
    pub tiles: &'a [u8],
    pub row_scale: Vec<f32>,
    pub col_scale: Vec<f32>,
    pub sqnr_db: f64,
    /// Checkpoint tensors stacked row-wise into this matrix (itself if not merged).
    pub parts: Vec<String>,
}

pub struct Dense<'a> {
    pub name: &'a str,
    pub dtype: &'a str,
    pub shape: Vec<usize>,
    pub bytes: &'a [u8],
}

/// Memory-mapped reader.
pub struct Container {
    map: Mmap,
    header: Value,
}

impl Container {
    pub fn open(path: &Path) -> Result<Self> {
        let file = File::open(path)?;
        // SAFETY: containers are immutable once written.
        let map = unsafe { Mmap::map(&file)? };
        if map.len() < 16 || &map[..8] != MAGIC {
            return Err(invalid(format!("{} is not a XeFlash container", path.display())));
        }
        let hlen = u64::from_le_bytes(map[8..16].try_into().unwrap()) as usize;
        let end = 16usize.checked_add(hlen).filter(|e| *e <= map.len()).ok_or_else(|| invalid("bad header length"))?;
        let header: Value =
            serde_json::from_slice(&map[16..end]).map_err(|e| invalid(format!("container header: {e}")))?;
        if !header["tensors"].is_array() {
            return Err(invalid("container header has no tensor list"));
        }
        Ok(Container { map, header })
    }

    pub fn meta(&self) -> &Value {
        &self.header["meta"]
    }

    fn entries(&self) -> &[Value] {
        self.header["tensors"].as_array().map(Vec::as_slice).unwrap_or(&[])
    }

    pub fn names(&self) -> impl Iterator<Item = (&str, &str)> {
        self.entries().iter().filter_map(|t| Some((t["name"].as_str()?, t["kind"].as_str()?)))
    }

    fn find(&self, name: &str, kind: &str) -> Result<&Value> {
        self.entries()
            .iter()
            .find(|t| t["name"] == name && t["kind"] == kind)
            .ok_or_else(|| invalid(format!("{kind} tensor {name} not found in container")))
    }

    fn blob(&self, v: &Value) -> Result<&[u8]> {
        let off = v["off"].as_u64().ok_or_else(|| invalid("blob without offset"))? as usize;
        let len = v["len"].as_u64().ok_or_else(|| invalid("blob without length"))? as usize;
        off.checked_add(len)
            .filter(|e| *e <= self.map.len())
            .map(|e| &self.map[off..e])
            .ok_or_else(|| invalid("blob lies outside the container (truncated file?)"))
    }

    fn f32s(&self, v: &Value) -> Result<Vec<f32>> {
        Ok(self.blob(v)?.chunks_exact(4).map(|b| f32::from_le_bytes([b[0], b[1], b[2], b[3]])).collect())
    }

    pub fn matrix(&self, name: &str) -> Result<Matrix<'_>> {
        let t = self.find(name, "matrix")?;
        let dim = |k: &str| t[k].as_u64().map(|v| v as usize).ok_or_else(|| invalid(format!("{name}: missing {k}")));
        let m = Matrix {
            name: t["name"].as_str().unwrap_or_default(),
            format: format_from(t["format"].as_str().unwrap_or_default())?,
            rows: dim("rows")?,
            cols: dim("cols")?,
            tiles: self.blob(&t["w"])?,
            row_scale: self.f32s(&t["row_scale"])?,
            col_scale: self.f32s(&t["col_scale"])?,
            sqnr_db: t["sqnr_db"].as_f64().unwrap_or(f64::NAN),
            parts: match t["parts"].as_array() {
                Some(a) => a.iter().filter_map(|v| v.as_str().map(str::to_string)).collect(),
                None => vec![name.to_string()],
            },
        };
        if m.row_scale.len() != m.rows || m.col_scale.len() != m.cols {
            return Err(invalid(format!("{name}: scale vectors do not match the shape")));
        }
        Ok(m)
    }

    pub fn dense(&self, name: &str) -> Result<Dense<'_>> {
        let t = self.find(name, "dense")?;
        Ok(Dense {
            name: t["name"].as_str().unwrap_or_default(),
            dtype: t["dtype"].as_str().unwrap_or_default(),
            shape: t["shape"].as_array().map(|a| a.iter().filter_map(|v| v.as_u64().map(|v| v as usize)).collect()).unwrap_or_default(),
            bytes: self.blob(&t["data"])?,
        })
    }
}
