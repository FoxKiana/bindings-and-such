
module gen;
import bindgen, std::io;

fn void main()
{
  @generate(&glfw, "glfw", "glfw3.h", { "vulkan" });
}

fn void glfw(String src, String out)
{
  BGTransCallbacks transfns = {
    .func = fn String(String str, Allocator alloc) =>
      str.strip("glfw").pascal_to_camel(alloc),

    .variable = &bgstr::camel_to_snake,

    .constant = fn String(String str, Allocator alloc) =>
      str == "APIENTRY" ? "" :
      str == "GLAPIENTRY" ? "" : // ignore APIENTRY
      str.strip("GLFW_").copy(alloc),
  };

  BGGenCallbacks gen_fns = {
    .module_wrap = &get_module_wrap,
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

  bg::translate_header(src, opts, transfns, gen_fns)!!;
}

fn BGModuleWrap get_module_wrap(String name, Allocator alloc)
{
  switch (name)
  {
    case "glfwGetInstanceProcAddress":
    case "glfwGetPhysicalDevicePresentationSupport":
    case "glfwCreateWindowSurface":
      return { "$defined(env::GLFW_INCLUDE_VULKAN) &&& env::GLFW_INCLUDE_VULKAN", "vulkan" };
    default:
      return {};
  }
}


