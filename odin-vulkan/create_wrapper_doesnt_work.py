# I got this from a gist in the internet, don't remember where...

import re
import urllib.request as req
from tokenize import tokenize
from io import BytesIO
import string
import os.path
import math

if not os.path.isfile("vulkan_core.h"):
    src = req.urlopen("https://raw.githubusercontent.com/KhronosGroup/Vulkan-Headers/master/include/vulkan/vulkan_core.h").read().decode('utf-8')
    with open("vulkan_core.h", "w") as f:
        f.write(src)
if not os.path.isfile("vulkan_win32.h"):
    src = req.urlopen("https://raw.githubusercontent.com/KhronosGroup/Vulkan-Headers/master/include/vulkan/vulkan_win32.h").read().decode('utf-8')
    with open("vulkan_win32.h", "w") as f:
        f.write(src)

src, win32_src = "", ""
with open("vulkan_core.h", "r") as f:
    src = f.read()
with open("vulkan_win32.h", "r") as f:
    win32_src = f.read()


def no_vk(t):
    t = t.replace('Vk', '')
    t = t.replace('PFN_vk', 'Proc')
    t = t.replace('VK_', '')
    return t

def convert_type(t):
    table = {
        "Bool32":      'b32',
        "float":       'f32',
        "uint32_t":    'u32',
        "uint64_t":    'u64',
        "size_t":      'int',
        "float":       'f32',
        'int32_t':     'i32',
        'int':         'c.int',
        'uint8_t':     'u8',
        "uint16_t":    'u16',
        "char":        "byte",
        "void":        "void",
        "void*":       "rawptr",
        "const void*": 'rawptr',
        "const char*": 'cstring',
        "const char* const*": 'cstring_array',
        "const ObjectTableEntryNVX* const*": "^^Object_Table_Entry_NVX",
        "struct BaseOutStructure": "Base_Out_Structure",
        "struct BaseInStructure":  "Base_In_Structure",
        'v': '',
     }

    if t in table.keys():
        return table[t]

    if t == "":
        return t
    elif t.endswith("*"):
        if t.startswith("const"):
            ttype = t[6:len(t)-1]
            return "^{}".format(convert_type(ttype))
        else:
            ttype = t[:len(t)-1]
            return "^{}".format(convert_type(ttype))
    elif t[0].isupper():
        return fix_def(t)

    return t

def parse_array(n, t):
    name, length = n.split('[')
    length = no_vk(length[0:len(length)-1])
    type_ = "[{}]{}".format(length, do_type(t))
    return name, type_

def remove_prefix(text, prefix):
    if text.startswith(prefix):
        return text[len(prefix):]
    return text
def remove_suffix(text, suffix):
    if text.endswith(suffix):
        return text[:-len(suffix)]
    return text


def to_snake_case(name):
    s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()

ext_suffixes = ["KHR", "EXT", "AMD", "NV", "NVX", "GOOGLE"]
ext_suffixes_title = [ext.title() for ext in ext_suffixes]


def fix_dim(name):
    # return name
    dims = ["1_D", "2_D", "3_D", "1_d", "2_d", "3_d"]
    for d in dims:
        if name.endswith(d):
            name = name[:-2]+name[-1:]
            break
        elif d in name:
            elem = "_"+d[0]+d[2]+"_"
            name = name.replace(d, elem)
            break
    if name[0].islower():
        return name.lower()
    return name

def fix_arg(arg):
    name = to_snake_case(arg)

    # Remove useless pointer identifier in field name
    for p in ('s_', 'p_', 'pp_', 'pfn_'):
        if name.startswith(p):
            name = name[len(p)::]
    name = name.replace("__", "_")

    return fix_dim(name)


def fix_ext_suffix(name):
    for ext in ext_suffixes_title:
        if name.endswith(ext):
            start = name[:-len(ext)]
            end = name[-len(ext):].upper()
            return start+end
    return name
def fix_def(name):
    name = to_snake_case(name).title()
    name = fix_ext_suffix(name)
    return fix_dim(name)

def is_int(x):
    try:
        int(x)
        return True
    except ValueError:
        return False

def fix_enum_arg(name, is_flag_bit=False):
    print(name)
    name = name.title()
    name = fix_ext_suffix(name)
    if name[0].isdigit() and not name.startswith("0x") and not is_int(name):
        if name[1] == "D":
            name = name[1] + name[0] + (name[2:] if len(name) > 2 else "")
        else:
            name = "_"+name
    if is_flag_bit:
        name = name.replace("_Bit", "")
    return fix_dim(name)

def do_type(t):
    return convert_type(no_vk(t)).replace("_Flag_Bits", "_Flags")

def parse_handles_def(f):
    f.write("// Handles types\n")
    handles = [fix_def(h) for h in re.findall("VK_DEFINE_HANDLE\(Vk(\w+)\)", src, re.S)]

    max_len = max(len(h) for h in handles)
    for h in handles:
        f.write("{} :: distinct Handle;\n".format(h.ljust(max_len)))

    handles_non_dispatchable = [fix_def(h) for h in re.findall("VK_DEFINE_NON_DISPATCHABLE_HANDLE\(Vk(\w+)\)", src, re.S)]
    max_len = max(len(h) for h in handles_non_dispatchable)
    for h in handles_non_dispatchable:
        f.write("{} :: distinct Non_Dispatchable_Handle;\n".format(h.ljust(max_len)))


flags_defs = set()

def parse_flags_def(f):
    names = [fix_def(n) for n in re.findall("typedef VkFlags Vk(\w+?);", src)]

    global flags_defs
    flags_defs = set(names)

def fix_enum_name(name, prefix, suffix, is_flag_bit):
    print("fixing:", name, prefix)
    name = remove_prefix(name, prefix)
    if suffix:
        name = remove_suffix(name, suffix)
    if name.startswith("0x"):
        if is_flag_bit:
            return str(int(math.log2(int(name, 16))))
        return name
    return fix_enum_arg(name, is_flag_bit)


def fix_enum_value(value, prefix, suffix, is_flag_bit):
    v = no_vk(value)
    g = tokenize(BytesIO(v.encode('utf-8')).readline)
    tokens = [val for _, val, _, _, _ in g]
    assert len(tokens) > 2
    tokens = tokens[1:-1]
    tokens = [fix_enum_name(token, prefix, suffix, is_flag_bit) for token in tokens]
    return ''.join(tokens)

def parse_constants(f):
    data = re.findall(r"#define VK_((?:"+'|'.join(ext_suffixes)+r")\w+)\s*(.*?)\n", src, re.S)
    if len(data) == 0:
        pass
    f.write("// Vendor Constants\n")
    max_len = max(len(name) for name, value in data)
    for name, value in data:
        f.write("{}{} :: {};\n".format(name, "".rjust(max_len-len(name)), value))
    f.write("\n")


def parse_enums(f):
    f.write("// Enums\n")

    data = re.findall("typedef enum Vk(\w+) {(.+?)} \w+;", src, re.S)

    generated_flags = set()

    for name, fields in data:
        enum_name = fix_def(name)

        is_flag_bit = False
        if "_Flag_Bits" in enum_name:
            is_flag_bit = True
            flags_name = enum_name.replace("_Flag_Bits", "_Flags")
            enum_name = enum_name.replace("_Bits", "")
            generated_flags.add(flags_name)
            f.write("{} :: distinct bit_set[{}; u32];\n".format(flags_name, enum_name))


        if is_flag_bit:
            f.write("{} :: enum u32 {{\n".format(fix_def(name).replace("_Flag_Bits", "_Flag")))
        else:
            f.write("{} :: enum c.int {{\n".format(fix_def(name)))
        prefix = to_snake_case(name).upper()

        suffix = None
        for ext in ext_suffixes:
            prefix_new = remove_suffix(prefix, "_"+ext)
            if prefix_new != prefix:
                assert suffix is None
                suffix = "_"+ext
            prefix = prefix_new
        prefix = remove_suffix(prefix, "_FLAG_BITS")
        prefix += "_"

        ff = []
        for name, value in re.findall("VK_(\w+?) = (.*?)(?:,|})", fields, re.S):
            n = fix_enum_name(name, prefix, suffix, is_flag_bit)
            v = fix_enum_value(value, prefix, suffix, is_flag_bit)
            ff.append((n, v))

        max_len = max(len(n) for n, v in ff)

        for n, v in ff:
            f.write("\t{} = {},\n".format(n.ljust(max_len), v))
        f.write("}\n\n")

    unused_flags = [flag for flag in flags_defs if flag not in generated_flags]

    max_len = max(len(flag) for flag in unused_flags)
    for flag in unused_flags:
        f.write("{} :: distinct Flags;\n".format(flag.ljust(max_len)))



def parse_structs(f):
    data = re.findall("typedef (struct|union) Vk(\w+?) {(.+?)} \w+?;", src, re.S)

    for _type, name, fields in data:
        fields = re.findall("\s+(.+?)\s+([_a-zA-Z0-9[\]]+);", fields)
        f.write("{} :: struct ".format(fix_def(name)))
        if _type == "union":
            f.write("#raw_union ")
        f.write("{\n")

        ffields = []
        for type_, fname in fields:
            if '[' in fname:
                fname, type_ = parse_array(fname, type_)
            comment = None
            n = fix_arg(fname)
            if "Flag_Bits" in type_:
                comment = " // only single bit set"
            t = do_type(type_)
            if t == "Structure_Type" and n == "type":
                n = "s_type"

            ffields.append(tuple([n, t, comment]))

        max_len = max(len(n) for n, _, _ in ffields)

        for n, t, comment in ffields:
            k = max_len-len(n)+len(t)
            f.write("\t{}: {},{}\n".format(n, t.rjust(k), comment or ""))


        f.write("}\n\n")

        # Some struct name that are not redefined automatically
        if name in ("MemoryRequirements2",):
            f.write("Memory_Requirements2_KHR :: Memory_Requirements2;\n\n")


procedure_map = {}

def parse_procedures(f):
    data = re.findall("typedef (\w+\*?) \(\w+ \*(\w+)\)\((.+?)\);", src, re.S)

    ff = []

    for rt, name, fields in data:
        proc_name = fix_def(no_vk(name))
        pf = [(do_type(t), fix_arg(n)) for t, n in re.findall("(?:\s*|)(.+?)\s*(\w+)(?:,|$)", fields)]
        data_fields = ', '.join(["{}: {}".format(n, t) for t, n in pf if t != ""])

        ts = "proc\"c\"({})".format(data_fields)
        rt_str = do_type(rt)
        if rt_str != "void":
            ts += " -> {}".format(rt_str)

        procedure_map[proc_name] = ts
        ff.append( (proc_name, ts) )

    max_len = max(len(n) for n, t in ff)

    for n, t in ff:
        f.write("{} :: #type {};\n".format(n.ljust(max_len), t))

def group_functions(f):
    data = re.findall("typedef (\w+\*?) \(\w+ \*(\w+)\)\((.+?)\);", src, re.S)
    group_map = {"Instance":[], "Device":[], "Loader":[]}

    for rt, vkname, fields in data:
        fields_types_name = [do_type(t) for t in re.findall("(?:\s*|)(.+?)\s*\w+(?:,|$)", fields)]
        table_name = fields_types_name[0]
        name = no_vk(vkname)

        nn = (fix_arg(name).lower(), fix_ext_suffix(name))

        if table_name in ('Device', 'Queue', 'CommandBuffer') and name != 'GetDeviceProcAddr':
            group_map["Device"].append(nn)
        elif table_name in ('Instance', 'PhysicalDevice') or name == 'GetDeviceProcAddr':
            group_map["Instance"].append(nn)
        elif table_name in ('rawptr', '', 'DebugReportFlagsEXT') or name == 'GetInstanceProcAddr':
            # Skip the allocation function and the dll entry point
            pass
        else:
            group_map["Loader"].append(nn)

    for group_name, group_lines in group_map.items():
        f.write("// {} Procedures\n".format(group_name))
        max_len = max(len(name) for name, _ in group_lines)
        for name, vk_name in group_lines:
            type_str = procedure_map[fix_def(vk_name)]
            f.write('{}: {};\n'.format(remove_prefix(name, "proc_"), fix_def(name).rjust(max_len)))
        f.write("\n")

    """
    f.write("load_proc_addresses :: proc(set_proc_address: Set_Proc_Address_Type) {\n")
    for group_name, group_lines in group_map.items():
        f.write("\t// {} Procedures\n".format(group_name))
        max_len = max(len(name) for name, _ in group_lines)
        for name, vk_name in group_lines:
            k = max_len - len(name)
            f.write('\tset_proc_address(&{}, {}"vk{}");\n'.format(
                remove_prefix(name, 'proc_'),
                "".ljust(k),
                remove_prefix(vk_name, 'Proc'),
            ))
        f.write("\n")
    f.write("}\n")
    """



BASE = """
//
// Vulkan wrapper generated from "https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/master/include/vulkan/vulkan_core.h"
//
package vulkan

import "core:c"
"""[1::]


# with open("basic_types.odin", 'w') as f:
with open("vk2.odin", 'w') as f:
    f.write(BASE)
    f.write("""
API_VERSION_1_0 :: (1<<22) | (0<<12) | (0);

// Base types
Flags       :: distinct u32;
Device_Size :: distinct u64;
Sample_Mask :: distinct u32;

Handle                  :: distinct rawptr;
Non_Dispatchable_Handle :: distinct u64;

Set_Proc_Address_Type :: #type proc(p: rawptr, name: cstring);


cstring_array :: ^cstring; // Helper Type

// Base constants
LOD_CLAMP_NONE                :: 1000.0;
REMAINING_MIP_LEVELS          :: ~u32(0);
REMAINING_ARRAY_LAYERS        :: ~u32(0);
WHOLE_SIZE                    :: ~u64(0);
ATTACHMENT_UNUSED             :: ~u32(0);
TRUE                          :: 1;
FALSE                         :: 0;
QUEUE_FAMILY_IGNORED          :: ~u32(0);
SUBPASS_EXTERNAL              :: ~u32(0);
MAX_PHYSICAL_DEVICE_NAME_SIZE :: 256;
UUID_SIZE                     :: 16;
MAX_MEMORY_TYPES              :: 32;
MAX_MEMORY_HEAPS              :: 16;
MAX_EXTENSION_NAME_SIZE       :: 256;
MAX_DESCRIPTION_SIZE          :: 256;
MAX_DEVICE_GROUP_SIZE_KHX     :: 32;
MAX_DEVICE_GROUP_SIZE         :: 32;
LUID_SIZE_KHX                 :: 8;
LUID_SIZE_KHR                 :: 8;
LUID_SIZE                     :: 8;
MAX_DRIVER_NAME_SIZE_KHR      :: 256;
MAX_DRIVER_INFO_SIZE_KHR      :: 256;
MAX_QUEUE_FAMILY_EXTERNAL     :: ~u32(0)-1;

"""[1::])
    parse_constants(f)
    parse_handles_def(f)
    f.write("\n\n")
    parse_flags_def(f)
# with open("enums.odin", 'w') as f:
    # f.write(BASE)
    f.write("\n")
    parse_enums(f)
    f.write("\n\n")
# with open("structs.odin", 'w') as f:
    # f.write(BASE)
    f.write("\n")
    parse_structs(f)
    f.write("\n\n")
# with open("procedures.odin", 'w') as f:
    # f.write(BASE)
    f.write("\n")
    parse_procedures(f)
    f.write("\n\n")
    group_functions(f)
