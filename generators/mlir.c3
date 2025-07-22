
module gen;
import bindgen, std::io;

fn void main()
{
    @generate(&mlir, "mlir", "mlir-c/Entrance.h");
}

fn void mlir(String src, String out)
{
    BGTransCallbacks transfns =
    {
        .func = fn (name, alloc)
        {
            return name.strip("mlir").camel_to_snake(alloc);
        },

        .constant = fn (name, alloc)
        {
            switch (true) {
                case name.contains("DEFINE_C_API_STRUCT"):
                    return "";
            }

            if (is_screaming(name)) return name;

            return name.strip("Mlir").pascal_to_screaming(alloc);
        },

        .func_macro = fn (name, alloc)
        {
            switch (true) {
                case name.contains("DECLARE_CAPI_DIALECT_REGISTRATION"):
                case name.contains("DEFINE_C_API_STRUCT"):
                    return "";
            }
            return name;
        },

        .variable = fn (name, alloc)
        {
            switch (name)
            {
                case "module": return "module_";
            }

            return name.camel_to_snake(alloc);
        },

        .type = fn (name, alloc)
        {
            return name.strip("Mlir").prepend("MLIR");
        }
    };

    BGOptions opts =
    {
        .out_name = out,
        .module_name = "mlir",
        .include_file = fn (path) => path.contains("mlir-c"),
        .clang_args = {
            "-I./headers",
        },
    };

    if (catch err = bg::translate_header(src, opts, transfns))
    {
        io::printn(err);
    }
}

fn String String.prepend(self, String prefix)
{
    DString out;
    out.init(mem);
    defer out.free();

    out.append_chars(prefix);
    out.append_chars(self);

    return out.str_view().copy(mem);
}

fn bool is_screaming(String name)
{
    return name == "MLIR_ENABLE_EXPENSIVE_PATTERN_API_CHECKS" ||
           name == "MLIR_ENABLE_PDL_IN_PATTERNMATCH" ||
           name == "MLIR_ENABLE_NVPTXCOMPILER" ||
           name == "MLIR_ENABLE_ROCM_CONVERSIONS" ||
           name == "MLIR_CAPI_DWARF_ADDRESS_SPACE_NULL";
}
