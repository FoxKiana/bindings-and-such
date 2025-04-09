
module gen;
import std::io;

/// Entry point
fn void main(String[] args)
{
  io::printfn("--- Current directory: %s", path::cwd(tmem)!!);
  
  @generate(args, "vulkan/vulkan.h", "vulkan");
  @generate(args, "glfw3.h", "glfw");
  
}


<*
 @return "true if args contain $name"
*>
macro bool @generate(String[] args, String $hname, String $name)
{
  io::printfn("--- Generating " +++ $name);
  $if $hname == "":
    $hname = $name;
  $endif

  if (args.len == 1 || args.contains($name)) 
  {
    $eval($name)("./headers/" +++ $hname, "./libs/" +++ $name +++ ".c3l/" +++ $name +++ ".c3i");
    return true;
  }
  else
  {
    return false;
  }
}

macro bool String[].contains(self, String str) 
{
  return @ok(array::index_of(self, str));
}

