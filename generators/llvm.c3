
module gen;
import bindgen, std::io;

fn void main()
{
    @generate(&llvm, "llvm", "llvm-c/Entrance.h");
}

fn void llvm(String src, String out)
{
    BGTransCallbacks transfns =
    {
        .func = fn (name, alloc)
        {
            name = name.strip("LLVM").strip("llvm_");
            return name.pascal_to_snake(alloc);
        },

        .constant = fn (name, alloc)
        {
            switch (name) {
                case "LLVM_C_STRICT_PROTOTYPES_BEGIN":
                case "LLVM_C_STRICT_PROTOTYPES_END":
                case "LLVM_C_EXTERN_C_BEGIN":
                case "LLVM_C_EXTERN_C_END":
                case "LLVM_DISASSEMBLER":
                case "LLVM_ASM_PARSER":
                case "LLVM_ASM_PRINTER":
                case "LLVM_TARGET":
                    return "";
            }
      
            if (name.contains("Disassembler"))
            {
                io::printfn("NAME: %s", name);
            }

            name = name.strip("LLVM");

            if (name.is_screaming())
            {
                return name.copy(alloc);
            } else if (name.starts_with("Disassembler"))
            {
                // TODO: something with that
                return name.snake_to_screaming(alloc);
            } else
            {
                // return name.copy(alloc);
                return name.pascal_to_screaming(alloc);
            }
        },

        .func_macro = fn (name, alloc)
        {
            switch (name)
            {
                case "LLVM_ATTRIBUTE_C_DEPRECATED":
                case "LLVM_FOR_EACH_VALUE_SUBCLASS":
                case "LLVM_DECLARE_VALUE_CAST":
                    return "";
            }

            return name.strip("LLVM_").screaming_to_snake(alloc);
        },

        .variable = fn (name, alloc)
        {
            switch (name)
            {
                case "Fn": return "fn_";
                case "If": return "if_";
                case "Switch": return "switch_";
                case "Catch": return "catch_";
                case "Else": return "else_";
                case "Alias": return "alias_";
                case "Asm": return "asm_";
                case "Module": return "module_";
                case "Var": return "var_";
            }
            return name.camel_to_snake(alloc);
        },

        .type = fn (name, alloc)
        {
            switch (name)
            {
                case "off_t": return "isz";
            }
            return name.copy(alloc).snake_to_pascal(alloc);
        }
    };

    BGOptions opts =
    {
        .out_name = out,
        .module_name = "llvm",
        .include_file = fn (path) => path.contains("llvm-c"),
        .clang_args = {
            "-I./headers",
        },
    };

    bg::translate_header(src, opts, transfns)!!; 
}

macro bool String.is_snake(String name) @local =>
    name.starts_with("lto") 
    || name.starts_with("thinlto")
    || name.starts_with("blake3")
    || name.starts_with("llvm_blake3");

macro bool String.is_screaming(String name) @local =>
    name.starts_with("BLAKE3")
    || name.starts_with("LTO")
    || name.starts_with("REMARKS");
