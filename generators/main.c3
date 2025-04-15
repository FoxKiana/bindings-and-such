
module gen;
import std::io, std::os;

/// Entry point
fn void main(String[] args)
{
  io::printfn("--- Current directory: %s", path::cwd(tmem)!!);
  
  @generate(args, "vulkan/vulkan.h", "vulkan");
  @generate(args, "glfw3.h", "glfw", "vulkan");
}

<*
 vaargs - dependencies
 @return "true if args contain $name"
*>
macro bool @generate(String[] args, String $hname, String $name, ...)
{
  $if $hname == "":
    $hname = $name;
  $endif

  if (args.len == 1 || args.contains($name)) 
  {
    var $res = "./libs/" +++ $name +++ ".c3l/" +++ $name +++ ".c3i";

    io::printfn("--- Generating " +++ $name);
    $eval($name)("./headers/" +++ $hname, $res);

    io::printfn("--- Checking " +++ $name);
    @check($res, $vasplat);
  
    return true;
  }
  else
  {
    return false;
  }
}

macro void @check(String $name, ...)
{
  var $list = { "c3c", "compile", "-C", $name, "--libdir", "./libs/" };

  $foreach $x : {$vasplat}:
    $list = $list +++ "--lib" +++ $x;
  $endforeach

  SubProcess proc = process::create($list, { .inherit_environment = true })!!;
  defer proc.destroy();
  proc.join()!!;

  usz len = 1;
  while (len)
  {
    char[512] buffer;
    len = proc.read_stderr(&buffer, buffer.len)!!;
    io::eprint((String) buffer[:len]);
  }
}

macro bool String[].contains(self, String str) 
{
  return @ok(array::index_of(self, str));
}

