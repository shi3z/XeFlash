//! Memory-mapped reader for a Hugging Face checkpoint directory
//! (`model-0000x-of-0000y.safetensors` shards). Nothing is copied: tensors are
//! views into the mapped files, so a 54 GB checkpoint can be walked with a
//! small resident set.

use std::collections::BTreeMap;
use std::fs::File;
use std::path::{Path, PathBuf};

use memmap2::Mmap;
use xeflash_core::{Error, Result, bf16_to_f32};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Dtype {
    Bf16,
    F16,
    F32,
    Other,
}

struct Entry {
    shard: usize,
    dtype: Dtype,
    shape: Vec<usize>,
    begin: usize,
    end: usize,
}

pub struct Checkpoint {
    shards: Vec<(PathBuf, Mmap)>,
    tensors: BTreeMap<String, Entry>,
}

pub struct TensorView<'a> {
    pub name: &'a str,
    pub dtype: Dtype,
    pub shape: &'a [usize],
    pub bytes: &'a [u8],
}

fn invalid(msg: impl Into<String>) -> Error {
    Error::Invalid(msg.into())
}

impl Checkpoint {
    /// Open every `*.safetensors` shard in `dir`.
    pub fn open(dir: &Path) -> Result<Self> {
        let mut paths: Vec<PathBuf> = std::fs::read_dir(dir)?
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| p.extension().is_some_and(|x| x == "safetensors"))
            .collect();
        paths.sort();
        if paths.is_empty() {
            return Err(invalid(format!("no .safetensors files in {}", dir.display())));
        }
        let mut shards = Vec::new();
        let mut tensors = BTreeMap::new();
        for (shard, path) in paths.into_iter().enumerate() {
            let file = File::open(&path)?;
            // SAFETY: the checkpoint is treated as read-only input; it must not
            // be modified while a conversion is running.
            let map = unsafe { Mmap::map(&file)? };
            if map.len() < 8 {
                return Err(invalid(format!("{} is truncated", path.display())));
            }
            let hlen = u64::from_le_bytes(map[..8].try_into().unwrap()) as usize;
            let data0 = 8usize
                .checked_add(hlen)
                .filter(|end| *end <= map.len())
                .ok_or_else(|| invalid(format!("{} has a bad header length", path.display())))?;
            let header: serde_json::Value = serde_json::from_slice(&map[8..data0])
                .map_err(|e| invalid(format!("{}: header is not JSON: {e}", path.display())))?;
            let obj = header.as_object().ok_or_else(|| invalid("safetensors header is not an object"))?;
            for (name, meta) in obj {
                if name == "__metadata__" {
                    continue;
                }
                let bad = || invalid(format!("{}: malformed entry for {name}", path.display()));
                let dtype = match meta["dtype"].as_str().ok_or_else(bad)? {
                    "BF16" => Dtype::Bf16,
                    "F16" => Dtype::F16,
                    "F32" => Dtype::F32,
                    _ => Dtype::Other,
                };
                let shape: Vec<usize> = meta["shape"]
                    .as_array()
                    .ok_or_else(bad)?
                    .iter()
                    .map(|v| v.as_u64().map(|v| v as usize).ok_or_else(bad))
                    .collect::<Result<_>>()?;
                let offs = meta["data_offsets"].as_array().ok_or_else(bad)?;
                let begin = data0 + offs.first().and_then(|v| v.as_u64()).ok_or_else(bad)? as usize;
                let end = data0 + offs.get(1).and_then(|v| v.as_u64()).ok_or_else(bad)? as usize;
                if begin > end || end > map.len() {
                    return Err(invalid(format!("{}: {name} lies outside the file (truncated download?)", path.display())));
                }
                tensors.insert(name.clone(), Entry { shard, dtype, shape, begin, end });
            }
            shards.push((path, map));
        }
        Ok(Checkpoint { shards, tensors })
    }

    pub fn names(&self) -> impl Iterator<Item = &str> {
        self.tensors.keys().map(|s| s.as_str())
    }

    pub fn get(&self, name: &str) -> Result<TensorView<'_>> {
        let (key, e) = self
            .tensors
            .get_key_value(name)
            .ok_or_else(|| invalid(format!("tensor {name} not found in checkpoint")))?;
        Ok(TensorView { name: key, dtype: e.dtype, shape: &e.shape, bytes: &self.shards[e.shard].1[e.begin..e.end] })
    }

    /// File that holds `name` (for reports).
    pub fn shard_of(&self, name: &str) -> Option<&Path> {
        self.tensors.get(name).map(|e| self.shards[e.shard].0.as_path())
    }
}

impl TensorView<'_> {
    pub fn numel(&self) -> usize {
        self.shape.iter().product()
    }

    /// Decode to f32 (exact for bf16 / f16 / f32 sources).
    pub fn to_f32(&self) -> Result<Vec<f32>> {
        let n = self.numel();
        match self.dtype {
            Dtype::Bf16 if self.bytes.len() == n * 2 => {
                Ok(self.bytes.chunks_exact(2).map(|b| bf16_to_f32(u16::from_le_bytes([b[0], b[1]]))).collect())
            }
            Dtype::F16 if self.bytes.len() == n * 2 => {
                Ok(self.bytes.chunks_exact(2).map(|b| f16_to_f32(u16::from_le_bytes([b[0], b[1]]))).collect())
            }
            Dtype::F32 if self.bytes.len() == n * 4 => {
                Ok(self.bytes.chunks_exact(4).map(|b| f32::from_le_bytes([b[0], b[1], b[2], b[3]])).collect())
            }
            _ => Err(invalid(format!("tensor {} has an unsupported dtype or size", self.name))),
        }
    }
}

fn f16_to_f32(h: u16) -> f32 {
    let sign = ((h >> 15) as u32) << 31;
    let exp = ((h >> 10) & 0x1F) as i32;
    let man = (h & 0x3FF) as u32;
    let bits = match exp {
        0 if man == 0 => sign,
        0 => {
            // subnormal: normalise
            let shift = man.leading_zeros() - 21;
            let man = (man << shift) & 0x3FF;
            sign | (((113 - shift as i32) as u32) << 23) | (man << 13)
        }
        31 => sign | 0x7F80_0000 | (man << 13),
        _ => sign | (((exp + 112) as u32) << 23) | (man << 13),
    };
    f32::from_bits(bits)
}

#[cfg(test)]
mod tests {
    use super::f16_to_f32;

    #[test]
    fn f16_values() {
        assert_eq!(f16_to_f32(0x3C00), 1.0);
        assert_eq!(f16_to_f32(0xC000), -2.0);
        assert_eq!(f16_to_f32(0x0001), 2f32.powi(-24));
        assert_eq!(f16_to_f32(0x7BFF), 65504.0);
        assert!(f16_to_f32(0x7E00).is_nan());
    }
}
