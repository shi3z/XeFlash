//! Model files: the original checkpoint (safetensors) and, later, the XeFlash
//! container.

pub mod container;
pub mod safetensors;

pub use container::{Container, ContainerWriter};
pub use safetensors::{Checkpoint, Dtype, TensorView};
