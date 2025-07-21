
module gen;
import std::io, std::os;

alias GenCallback = fn void (String src, String out);

<*
 See usage in 'generators/glfw.c3' or other generators

 @param cb : "Takes String src and String out - source and output files. It has to perform all the translation via bindgen bg::translate_header function"
 @param $name : "Name of the resulting library. For instance 'glfw' will result into 'glfw.c3l' with 'glfw.c3i' interface file"
 @param $hname : "Name of the input header inside of 'headers' directory"
 @param $deps : `Dependencies to use. Those are .c3l libraries inside of bc3 repo. For example, if we need 'vulkan.c3l' as the dependency for 'glfw.c3l', we write {"glfw"}`
 @param $no_check : "If true, supresses checks"
*>
macro void @generate(GenCallback cb, String $name, String $hname, String[] $deps = {}, bool $no_check = false)
{
  $if $hname == "":
    $hname = $name;
  $endif

  var $res = "./libs/" +++ $name +++ ".c3l/" +++ $name +++ ".c3i";

  io::printfn("--- Generating " +++ $name);
  cb("./headers/" +++ $hname, $res);

  $if !$no_check:
    io::printfn("--- Checking " +++ $name);
    @check($res, $deps);
  $endif
}

<*
 Just a helper function. Don't use it in code
*>
macro void @check(String $name, String[] $deps) 
{
  var $list = { "c3c", "compile", "-C", $name, "--libdir", "./libs/" };

  $foreach $x : $deps:
    $list = $list +++ "--lib" +++ $x;
  $endforeach

  SubProcess proc = process::create($list, { .inherit_environment = true })!!;
  defer proc.destroy();
  proc.join()!!;

  usz len = 1;
  while (len) {
    char[512] buffer;
    len = proc.read_stderr(&buffer, buffer.len)!!;
    io::eprint((String) buffer[:len]);
  }
}

