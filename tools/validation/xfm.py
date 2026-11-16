"""Minimal reader of the XeFlash container for the Python reference."""
import json

import numpy as np


class Xfm:
    def __init__(self, path):
        self.mm = np.memmap(path, dtype=np.uint8, mode="r")
        assert bytes(self.mm[:8]) == b"XFLASH01", "not a XeFlash container"
        hlen = int(np.frombuffer(self.mm[8:16], "<u8")[0])
        header = json.loads(bytes(self.mm[16:16 + hlen]))
        self.tensors = {t["name"]: t for t in header["tensors"]}

    def _blob(self, b):
        return self.mm[b["off"]:b["off"] + b["len"]]

    def is_matrix(self, name):
        return name in self.tensors and self.tensors[name]["kind"] == "matrix"

    def matrix(self, name):
        """Reconstructed float32 weights: row_scale * (q + 0.5) * col_scale."""
        t = self.tensors[name]
        assert t["format"] == "s4", t["format"]
        rows, cols = t["rows"], t["cols"]
        rs = np.frombuffer(self._blob(t["row_scale"]), "<f4")
        cs = np.frombuffer(self._blob(t["col_scale"]), "<f4")
        tiles = np.frombuffer(self._blob(t["w"]), "<u4").reshape(rows // 16, cols // 32, 4, 16)
        out = np.empty((rows, cols), np.float32)
        step = 256  # row blocks per chunk, bounds temporary memory
        for b0 in range(0, rows // 16, step):
            a = tiles[b0:b0 + step]                                   # [rb][tile][reg][lane]
            nib = np.stack([(a >> (4 * j)) & 15 for j in range(8)], -1).astype(np.int8)
            nib = np.where(nib > 7, nib - 16, nib)                    # sign-extend
            q = nib.transpose(0, 3, 1, 2, 4).reshape(-1, cols)        # [rb][lane] x [tile][reg][j]
            r = rs[b0 * 16:b0 * 16 + q.shape[0]]
            out[b0 * 16:b0 * 16 + q.shape[0]] = r[:, None] * (q.astype(np.float32) + 0.5) * cs[None, :]
        return out
