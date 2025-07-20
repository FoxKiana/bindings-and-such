
module gen;
import bindgen;

fn void main() 
{
  @generate(&python, "python", "python3.12/Python.h");
}

fn void python(String src, String out)
{
  BGTransCallbacks transfns = {
    // .func = fn String(String name, Allocator alloc) =>
    //   name.strip("vk").pascal_to_camel(alloc),
    //
    // .type = &trans_type,

    .variable = fn (name, alloc) => 
      name.screaming_to_snake(alloc),
      
    .constant = fn (name, alloc) {
      if (name[0] == '_') return "";
      switch (name) {
        case "Py_MEMCPY":
          return "";
        default:
          return name.snake_to_screaming(alloc);
      }
    },

    .func_macro = fn (name, alloc) {
      if (name[0] == '_') return "";
      switch (name) {
        case "Py_LOCAL":
        case "Py_LOCAL_INLINE":
          return "";
        default:
          return name.copy(alloc);
      }
    },
  };

  BGGenCallbacks genfns = {
    // .func_macro = fn String(String name, Allocator alloc) =>
    //   get_func_macro_body(name).copy(alloc),
    //
    // .constant = fn String(String name, Allocator alloc) =>
    //   get_const_rhs(name).copy(alloc),
    //
    // .if_condition = fn String(String name, Allocator alloc) =>
    //   get_if_condition(name).copy(alloc),
  };

  BGOptions opts = {
    .out_name = out,
    .clang_args = {
      "-I./headers",
    },
    .module_name = "python",
    .skip_errors = false,
    .no_verbose = true,
    .include_file = fn bool(String path) => path.contains("python3.12"),
  };

  bg::translate_header(src, opts, transfns, genfns)!!;
}


