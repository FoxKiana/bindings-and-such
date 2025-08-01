
module bindgen::impl::ttor @private;
import bindgen::impl @public;
import std::io, clang, std::collections::list;

<*
 Translates global variable declaration and writes it to 'out'
 @require clang::getCursorKind(cursor) == clang::CURSOR_VAR_DECL : "Cursor must point to variable declaration"
 @return "Number of bytes written"
*>
fn usz? varDecl(
  GlobalVisitData* vd,
  CXCursor cursor)
@maydiscard => @pool() {
  CXType type = clang::getCursorType(cursor);

  if (clang::isConstQualifiedType(type)) {
    return ttor::constDecl(vd, cursor);
  } else {
    CXString cursor_spell = clang::getCursorSpelling(cursor);
    defer clang::disposeString(cursor_spell);
    String cursor_str = misc::convStr(cursor_spell);

    String rhs_val = "";
    if (misc::getTopChildrenNumber(cursor) > 0) {
      rhs_val = valgen::apply(tmem, cursor_str, vd.gen_fns.variable);
      if (rhs_val == "") {
        err::warn(vd.no_verbose, "Global variable '%s' contains default value and value generator function return empty string, so complete it manually", cursor_str);
      }
    }
    
    String? name = trans::apply(cursor_str, vd.trans_fns.variable);
    if (catch name) {
      err::warn(vd.no_verbose, "Global variable '%s' is ignored", cursor_str);
      return 0;
    }

    String? trans_type_str = trans::ctypeWithPFN(cursor, vd);
    if (catch trans_type_str) {
      CXString type_spell = clang::getTypeSpelling(type);
      defer clang::disposeString(type_spell);
      String type_str = misc::convStr(type_spell);

      err::warn(vd.no_verbose, "Can't translate global variable '%s' as it's type name '%s' is ignored", cursor_str, type_str);
      return 0;
    }

    valgen::moduleWrap(vd, cursor_str);

    WriteAttrs attrs = valgen::getWriteAttrs(tmem, cursor_str, vd.gen_fns);
    return wter::varDecl(vd.out, &vd.write_state, trans_type_str, name, rhs_val, attrs);
  }
}

<*
 Translates global constant declaration and writes it to 'out'
 @require clang::getCursorKind(cursor) == clang::CURSOR_VAR_DECL : "Cursor must point to variable declaration"
 @return "Number of bytes written"
*>
fn usz? constDecl(
  GlobalVisitData* vd, 
  CXCursor cursor) 
@maydiscard => @pool()
{
  CXString cursor_spell = clang::getCursorSpelling(cursor);
  defer clang::disposeString(cursor_spell);
  String cursor_str = misc::convStr(cursor_spell);

  ConstVisitData vd_const = { 
    .g = vd,
    .allocator = tmem,
    .val = valgen::apply(tmem, cursor_str, vd.gen_fns.constant),
  };

  // If value is not generated manually, visit tokens.
  if (vd_const.val == "")
  {
    // Visit rhs of var declaration and translate 
    // there everything, that is identifier
    clang::visitChildren(cursor, &vtor::constDecl, (CXClientData) &vd_const);
  }

  String? name = trans::apply(cursor_str, vd.trans_fns.constant);
  if (catch name)
  {
    err::warn(vd.no_verbose, "Constant '%s' is ignored", cursor_str);
    return 0;
  }

  String? trans_type_str = trans::ctypeWithPFN(cursor, vd);
  if (catch trans_type_str)
  {
    CXString type_spell = clang::getTypeSpelling(clang::getCursorType(cursor));
    defer clang::disposeString(type_spell);
    String type_str = misc::convStr(type_spell);

    err::warn(vd.no_verbose, "Can't translate constant '%s' as it's type name '%s' is ignored", cursor_str, type_str);
    return 0;
  }

  WriteAttrs attrs = valgen::getWriteAttrs(tmem, cursor_str, vd.gen_fns);
  return wter::constDecl(vd.out, &vd.write_state, trans_type_str, name, vd_const.val, attrs);
}

<*
 Translates enumDecl declaration and writes it to 'vd.out'
 @param [out] out_name : "The resulting name of an enum type. Might be needed as enum can be anonymous: in that case this variable is set to the underlying type name"
 @param out_alloc : "Allocator for allocating 'out_name'"

 @require clang::getCursorKind(cursor) == clang::CURSOR_ENUM_DECL : "Cursor must point to enum declaration"
 @return "Number of bytes written"
*>
fn usz? enumDecl(
  GlobalVisitData* vd, 
  CXCursor cursor,
  String* out_name = null,
  Allocator out_alloc = tmem) 
@maydiscard => @pool() 
{
  CXType enum_type = clang::getCursorType(cursor);
  CXString enum_spell = clang::getTypeSpelling(enum_type);
  defer clang::disposeString(enum_spell);
  String orig_enum_name = misc::convStr(enum_spell);
  
  CXType under_type = clang::getEnumDeclIntegerType(cursor);
  String? under_type_str = trans::ctype(under_type, vd);
  if (catch under_type_str) {
    CXString orig_under_type_spell = clang::getTypeSpelling(under_type);
    defer clang::disposeString(enum_spell);
    String orig_under_type_str = misc::convStr(orig_under_type_spell);

    err::warn(vd.no_verbose, "Can't translate enum '%s' as it's underlying type '%s' is ignored", orig_enum_name, orig_under_type_str);
    return 0;
  }

  EnumVisitData vd_enum = {
    .g = vd
  };

  switch (under_type.kind) {
    case clang::TYPE_UCHAR:
    case clang::TYPE_USHORT: 
    case clang::TYPE_UINT:      
    case clang::TYPE_ULONG:
    case clang::TYPE_ULONGLONG: 
      vd_enum.is_unsigned = true;
    default:
      vd_enum.is_unsigned = false;
  }

  WriteAttrs attrs;
  usz? acc;
  if (clang::isAnonymous_Cursor(cursor)) {
    CXType base = misc::getBaseType(enum_type);
    vd.types_table[base] = under_type_str;

    vd_enum.enum_name = under_type_str;
  } else {
    String? tmp = trans::ctype(enum_type, vd);
    if (catch tmp) {
      err::warn(vd.no_verbose, "Enum '%s' is ignored", orig_enum_name);
      return 0;
    }

    valgen::moduleWrap(vd, orig_enum_name);
    attrs = valgen::getWriteAttrs(tmem, orig_enum_name, vd.gen_fns);
    acc = wter::enumDecl(vd.out, &vd.write_state, tmp, under_type_str);
    
    vd_enum.enum_name = tmp;
  }

  if (out_name != null) *out_name = vd_enum.enum_name.copy(out_alloc);

  clang::visitChildren(cursor, &vtor::enumDecl, (CXClientData) &vd_enum);
  return acc;
}

<*
 Translates functions and writes it to 'vd.out'
 @require clang::getCursorKind(cursor) == clang::CURSOR_FUNCTION_DECL : "Cursor must point to function declaration"
 @returns "Number of bytes written"
*>
fn usz? func(
  GlobalVisitData* vd, 
  CXCursor cursor) 
@maydiscard => @pool()
{
  FuncVisitData vd_func = {
    .g = vd,
    .allocator = tmem,
  };

  vd_func.params.tinit(4);

  // Translate function parameters and store them into vd_func.params
  if (clang::visitChildren(cursor, &vtor::func, (CXClientData) &vd_func) != 0) return 0;
  
  CXString func_spell = clang::getCursorSpelling(cursor);
  defer clang::disposeString(func_spell);
  String func_str = misc::convStr(func_spell);

  String? trans_func_str = trans::apply(func_str, vd.trans_fns.func);
  if (catch trans_func_str)
  {
    err::warn(vd.no_verbose, "Function '%s' is ignored", func_str);
    return 0;
  }

  CXType ret_type = clang::getCursorResultType(cursor); 
  if (misc::isTypePFN(ret_type))
  {
    err::warn(vd.no_verbose, "Function '%s' returns a pointer to function, which I can't translate, skipping...", func_str);
    return 0;
  }

  String? trans_ret_type_str = trans::ctype(ret_type, vd);
  if (catch trans_ret_type_str)
  {
    CXString type_spell = clang::getTypeSpelling(ret_type);
    defer clang::disposeString(type_spell);
    String type_str = misc::convStr(type_spell);

    err::warn(vd.no_verbose, "Can't translate function '%s' as it's return type '%s' is ignored", func_str, type_str);
    return 0;
  }

  valgen::moduleWrap(vd, func_str);

  WriteAttrs attrs = valgen::getWriteAttrs(tmem, func_str, vd.gen_fns);
  return wter::func(vd.out, &vd.write_state, vd_func.params.array_view(), trans_ret_type_str, func_str, trans_func_str, attrs);
}

<*
 Translates macro definition and writes it to 'out'
 @require clang::getCursorKind(cursor) == clang::CURSOR_MACRO_DEFINITION : "Cursor must point to macro definition"
 @returns "Number of bytes written"
*>
fn usz? macroDef(
  GlobalVisitData* vd, 
  CXCursor cursor) 
@maydiscard
{
  return clang::isMacroFunctionLike_Cursor(cursor) ? 
    ttor::funcMacroDef(vd, cursor) :
    ttor::constMacroDef(vd, cursor);
}

<*
 Translates functional macro without generating it's body
*>
fn usz? funcMacroDef(
  GlobalVisitData* vd,
  CXCursor cursor)
@maydiscard => @pool()
{
  CXString macro_spell = clang::getCursorSpelling(cursor);
  defer clang::disposeString(macro_spell);
  String macro_str = misc::convStr(macro_spell);

  String? trans_macro_str = trans::apply(macro_str, vd.trans_fns.func_macro, tmem);
  if (catch trans_macro_str)
  {
    err::warn(vd.no_verbose, "Functional macro '%s' is ignored", macro_str);
    return 0;
  }

  String macro_body = valgen::apply(tmem, macro_str, vd.gen_fns.func_macro);
  if (macro_body == "") 
  {
    err::warn(vd.no_verbose, "Macro '%s' (@%s) is function-like and generator function returned empty string so you should complete it's body manually", macro_str, trans_macro_str);
  }

  List{String} params;
  params.tinit();

  CXTranslationUnit tu = clang::getTranslationUnit_Cursor(cursor);
  CXSourceRange sr = misc::getTrueCursorExtent(cursor); // We don't need to do getTrueCursorExtent as bug is not occured under macro declaration
  
  CXToken* tokens_ptr; uint tokens_len;
  clang::tokenize(tu, sr, &tokens_ptr, &tokens_len);
  defer clang::disposeTokens(tu, tokens_ptr, tokens_len);

  // Make a small tweak here. TODO: get rid of it
  if OUTER: (true) 
  {
    // First token is the name of a macro and second token is left brace so start from the third one
    misc::@iterateTokens(tokens_ptr[2..tokens_len-1], tu; CXToken* token, String token_str)
    {
      if (token_str == ")") break OUTER;
      if (token_str != ",")
      {
        String? trans_token_str = trans::apply(token_str, vd.trans_fns.variable, tmem);
        if (catch trans_token_str)
        {
          err::warn(vd.no_verbose, "Can't translate functional macro '%s' as it's parameter '%s' is ignored", macro_str, token_str);
          return 0;
        }

        params.push(trans_token_str);
      }
    };
  }

  valgen::moduleWrap(vd, macro_str);

  WriteAttrs attrs = valgen::getWriteAttrs(tmem, macro_str, vd.gen_fns);
  return wter::funcMacro(vd.out, &vd.write_state, params.array_view(), trans_macro_str, macro_body, attrs);
}

<*
 Translates macro which is not function-like, e.g.:
 `#define MY_MACRO 1` -> `const MY_MACRO = 1;`
*>
fn usz? constMacroDef(
  GlobalVisitData* vd, 
  CXCursor cursor) 
@maydiscard => @pool()
{
  CXString cursor_spell = clang::getCursorSpelling(cursor);
  defer clang::disposeString(cursor_spell);
  String cursor_str = misc::convStr(cursor_spell);

  String? trans_cursor_str = trans::apply(cursor_str, vd.trans_fns.constant, tmem); 
  if (catch trans_cursor_str)
  {
    err::warn(vd.no_verbose, "Constant '%s' is ignored", cursor_str);
    return 0;
  }

  String val = valgen::apply(tmem, cursor_str, vd.gen_fns.constant); 
  if (val == "")
  {
    String? t = trans::tokensUnderCursor(tmem, cursor, &vd.trans_fns);
    if (catch exc = t)
    {
      switch (exc)
      {
        case trans::IGNORE:
          err::warn(vd.no_verbose, "Can't translate constant '%s' as it's rhs comprises ignored name", cursor_str);
        case trans::EMPTY:
          err::warn(vd.no_verbose, "Macro '%s' doesn't have value, skipping...", cursor_str);
      }
      return 0;
    }

    val = t;
  }
 
  valgen::moduleWrap(vd, cursor_str);

  WriteAttrs attrs = valgen::getWriteAttrs(tmem, cursor_str, vd.gen_fns);
  return wter::constDecl(vd.out, &vd.write_state, "", trans_cursor_str, val, attrs);
}

<*
 Translates alias declaration and writes it to 'out'
 @require clang::getCursorKind(cursor) == clang::CURSOR_TYPEDEF_DECL : "Cursor must point to typedef declaration"
 @returns "Number of bytes written"
*>
fn usz? typedefDecl(
  GlobalVisitData* vd, 
  CXCursor cursor) 
@maydiscard => @pool()
{
  CXType type = clang::getCursorType(cursor);
  CXType under_type = clang::getTypedefDeclUnderlyingType(cursor);

  CXString type_spell = clang::getTypeSpelling(type);
  defer clang::disposeString(type_spell);
  String type_str = misc::convStr(type_spell);

  String? trans_type_str = trans::ctype(type, vd);
  if (catch trans_type_str)
  {
    err::warn(vd.no_verbose, "Alias '%s' is ignored", type_str);
    return 0;
  }

  valgen::moduleWrap(vd, type_str);
  WriteAttrs attrs = valgen::getWriteAttrs(tmem, type_str, vd.gen_fns);

  if (misc::isTypePFN(under_type)) {
    return ttor::pfnType(vd, trans_type_str, under_type, cursor, attrs);
  } else {
    // Translate alias
    String? under_type_name = trans::ctype(under_type, vd);
    if (catch under_type_name)
    {
      err::warn(vd.no_verbose, "Can't translate alias as it's underlying type '%s' is ignored", type_str);
      return 0;
    }

    if (trans_type_str != under_type_name) {
      return wter::typedefAlias(vd.out, &vd.write_state, trans_type_str, under_type_name, attrs);
    } else {
      // Do not write if aliases are equal
      return 0;
    }
  }
}

<*
 Translates structure declaration and writes it to 'out'
 @require clang::getCursorKind(cursor) == clang::CURSOR_STRUCT_DECL : "Cursor must point to structure declaration"
 @returns "Number of bytes written"
*>
fn usz? structDecl(
  GlobalVisitData* vd, 
  CXCursor cursor) 
@maydiscard => @pool()
{
  return ttor::recordDecl(vd, cursor, $is_union: false);
}

<*
 Union declaration and writes it to 'out'
 @require  clang::getCursorKind(cursor) == clang::CURSOR_UNION_DECL : "Cursor must point to union declaration"
 @returns "Number of bytes written"
*>
fn usz? unionDecl(
  GlobalVisitData* vd, 
  CXCursor cursor) 
@maydiscard
{
  return ttor::recordDecl(vd, cursor, $is_union: true);
}


// ------- Helpers, which are not called directly from global visitor

<*
 @param $is_union : "Made to avoid code repeatance"
 @param [out] out_name : "The resulting written name of a record. Must be freed after use via an allocator"
 @param out_alloc : "Allocator, which allocates 'out_name'"
*>
macro usz? recordDecl(
  GlobalVisitData* vd,
  CXCursor cursor, 
  bool $is_union,
  String* out_name = null,
  Allocator out_alloc = tmem)
@maydiscard => @pool()
{
  CXType rec_type = clang::getCursorType(cursor);
  String? rec_name = trans::ctype(rec_type, vd);

  CXString rec_spell = clang::getTypeSpelling(rec_type);
  defer clang::disposeString(rec_spell);
  String orig_rec_name = misc::convStr(rec_spell);

  if (catch rec_name) {
    $if $is_union:
      err::warn(vd.no_verbose, "Union '%s' is ignored", orig_rec_name);
    $else
      err::warn(vd.no_verbose, "Struct '%s' is ignored", orig_rec_name);
    $endif
    return 0;
  }
 
  if (clang::isAnonymous_Cursor(cursor)) {
    CXSourceLocation cursor_loc = clang::getCursorLocation(cursor);
    CUInt line, col;
    CXFile file;
    clang::getFileLocation(cursor_loc, &file, &line, &col, null);
    CXString file_spell = clang::getFileName(file);
    defer clang::disposeString(file_spell);
    String file_name = misc::convStr(file_spell);

    $if $is_union:
      err::warn(vd.no_verbose, "Can't translate union at %s:%d:%d as it's anonymous", file_name, line, col);
    $else
      err::warn(vd.no_verbose, "Can't translate struct at %s:%d:%d as it's anonymous", file_name, line, col);
    $endif
    return 0;
  }

  WriteAttrs attrs = valgen::getWriteAttrs(tmem, orig_rec_name, vd.gen_fns);

  // If no fields are defined, rec_type is incomplete.
  // Then we write it as typedef to void and wrap into
  // module if needed
  usz fields_len = misc::getTopChildrenNumber(cursor);
  if (fields_len == 0)  {
    valgen::moduleWrap(vd, orig_rec_name);
    return wter::typedefDist(vd.out, &vd.write_state, rec_name, "void", attrs);
  }

  FieldsVisitData vd_rec = {
    .g = vd,
    .allocator = tmem,
    .prev_inline = clang::getNullCursor(),
  };

  vd_rec.fields.init(vd_rec.allocator);

  // Translate record fields and store them into vd_rec.fields
  if (clang::visitChildren(cursor, &vtor::fields, (CXClientData) &vd_rec) != 0) return 0;

  C3Fields? c3_fields = algo::getC3Fields(tmem, vd_rec.fields);
  if (catch c3_fields) {
    $if $is_union:
      err::warn(vd.no_verbose, "Can't translate bit fields within union '%s', skipping...", orig_rec_name);
    $else
      err::warn(vd.no_verbose, "Can't translate bit fields within struct '%s', skipping...", orig_rec_name);
    $endif
    return 0;
  }

  if (c3_fields.bit.len() > 0) {
    $if $is_union:
      err::warn(vd.no_verbose, "Bit fields encountered within union '%s'!", orig_rec_name);
    $else
      err::warn(vd.no_verbose, "Bit fields encountered within struct '%s'!", orig_rec_name);
    $endif
  }

  // Write to out_name if needed
  if (out_name != null) *out_name = rec_name.copy(out_alloc);

  valgen::moduleWrap(vd, orig_rec_name);
  $if $is_union:
    return wter::unionDecl(vd.out, &vd.write_state, rec_name, &c3_fields, 0, attrs);
  $else
    return wter::structDecl(vd.out, &vd.write_state, rec_name, &c3_fields, 0, attrs);
  $endif
}

fn usz? pfnType(
  GlobalVisitData* vd, 
  String name,
  CXType type, 
  CXCursor cursor,
  WriteAttrs attribs = {}) 
@maydiscard => @pool()
{
  FuncVisitData vd_func = {
    .g = vd,
    .allocator = tmem,
  };

  vd_func.params.tinit(4);
  
  CXType ret_type = clang::getResultType(clang::getPointeeType(type));
  String? trans_ret_type_str = trans::ctype(ret_type, vd);

  if (catch trans_ret_type_str)
  {
    CXString ret_type_spell = clang::getTypeSpelling(ret_type);
    defer clang::disposeString(ret_type_spell);
    String ret_type_str = misc::convStr(ret_type_spell);

    CXString cursor_spell = clang::getCursorSpelling(cursor);
    defer clang::disposeString(cursor_spell);
    String cursor_str = misc::convStr(cursor_spell);

    err::warn(vd.no_verbose, "Can't translate function pointer alias '%s' as it's return type '%s' is ignored", cursor_str, ret_type_str);
    return 0;
  }

  // Translate function parameters and store them into vd_struct.fields
  if (clang::visitChildren(cursor, &vtor::func, (CXClientData) &vd_func) != 0) return 0;

  return wter::typedefFunc(vd.out, &vd.write_state, name, trans_ret_type_str, vd_func.params.array_view(), attribs: attribs);
}
