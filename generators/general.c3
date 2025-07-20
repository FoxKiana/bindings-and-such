
module gen;
import std::io, std::os;

alias GenCallback = fn void (String src, String out);

<*
 ... - dependencies
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

