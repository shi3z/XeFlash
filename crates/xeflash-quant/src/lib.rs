//! Weight and activation layouts for the Xe2 XMX systolic array.
//!
//! The GEMM kernels never reorder data at run time. Everything is put into the
//! order DPAS consumes at conversion time; this crate is the single definition
//! of that order (the layout was established on the B60 with
//! `kernels/probe/dpas_map.cpp`).

pub mod quantize;
pub mod tile;

pub use quantize::{QuantSpec, Quantized, quantize};
pub use tile::{pack_activations, pack_activations_bf16, pack_weights, pack_weights_bf16, split_a16, unpack_weights};
