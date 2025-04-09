
module gen @local;
import bindgen, std::io;

fn String get_if_condition(String str)
{
  switch (str)
  {
    case "glfwGetInstanceProcAddress":
    case "glfwGetPhysicalDevicePresentationSupport":
    case "glfwCreateWindowSurface":
      return "$defined(env::GLFW_INCLUDE_VULKAN) &&& env::GLFW_INCLUDE_VULKAN";
    default:
      return "";
  }
}

fn void glfw(String src, String out) @public
{
  BGTransCallbacks transfns = {
    .func = fn String(String str, Allocator alloc) =>
      str.strip("glfw").pascal_to_camel(alloc),

    .variable = &bgstr::camel_to_snake,

    .type = fn String(String str, Allocator alloc) => 
      str.map_basic_type(alloc) ?? str.copy(alloc),

    .constant = fn String(String str, Allocator alloc) =>
      str == "APIENTRY" ? "" :
      str == "GLAPIENTRY" ? "" : // ignore APIENTRY
      str.strip("GLFW_").copy(alloc),
  };

  BGGenCallbacks gen_fns = {
    .if_condition = fn String(String str, Allocator alloc) =>
      get_if_condition(str).copy(alloc),
  };

  BGOptions opts = {
    .out_name = out,
    .clang_args = { 
      "-I./headers",
      "-DGLFW_INCLUDE_VULKAN",
    },
    .module_name = "glfw",
    .no_verbose = true,
    .skip_errors = false,
  };

  bg::translate_header(src, transfns, opts, gen_fns)!!;
}


