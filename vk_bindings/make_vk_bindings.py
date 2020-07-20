

# // TODO: fix binding
# VkClearColorValue :: struct #raw_union {
#     float32: [4]f32,
#     int32: [4]i32,
#     uint32: [4]u32,
# }

# // TODO: fix VkResult enums, that should be negative
# VK_ERROR_OUT_OF_POOL_MEMORY = -1000069000,


import xml.etree.ElementTree as ET


def main():
    tree = ET.parse('vk.xml')

    root = tree.getroot()

    commands = None
    types = None
    enums = []
    enums_extra = {}
    for node in root:
        if node.tag == "types":
            types = parse_types(node)
        if node.tag == "enums":
            r = parse_enum(node)
            if r:
                enums.append(r)
        if node.tag == "commands":
            commands = parse_commands(node)
        if node.tag == "feature":
            parse_feature(node, enums_extra)
        if node.tag == "extensions":
            for extension in node:
                assert extension.tag == "extension"
                parse_feature(extension, enums_extra)

    enums_lines = []

    for enum in enums:
        enum_name = enum[0]
        enum_values = enum[1]
        extras = enums_extra.get(enum_name, None)
        if extras:
            enum_values += extras

        if enum_name == None:
            for value in enum_values:
                enums_lines.append("%s :: %s;\n" % value)
        else:
            enums_lines.append("%s :: enum c.int {" % enum_name)
            written_values = {}
            for value in enum_values:
                if value[0] in written_values:
                    assert value[1] == written_values[value[0]]
                else:
                    enums_lines.append("%s = %s," % value)
                    written_values[value[0]] = value[1]
            enums_lines.append("}\n")

    assert(commands)
    assert(types)

    enums_text = "\n".join(enums_lines)

    file = open("vk.odin", "w")
    file.write('''
package vulkan_bindings
import "core:strings"
import "core:c"

VK_MAKE_VERSION :: proc(major, minor, patch: u32) -> u32 {
    return major << 22 | minor << 12 | patch;
}

''')

    file.write(enums_text)
    file.write(types)

    file.write('''
foreign import vk { "../../../VulkanSDK/1.2.135.0/Lib/vulkan-1.lib" };

@(default_calling_convention="c")//, link_prefix="glfw")
foreign vk {
''')

    file.write(commands)
    file.write('''
}
''')
    file.close()


def append_or_create(src_dict, key, value):
    l = src_dict.get(key, None)
    if l == None:
        l = []
        src_dict[key] = l
    l.append(value)

def parse_feature(node, enums_dict):

    ext_number = node.attrib.get("number", None)
    for req in node:
        assert req.tag == "require"
        for child in req:
            if child.tag == "enum":
                name = child.attrib["name"]
                base = child.attrib.get("extends", None)
                if base == None:
                    value = child.attrib.get("value", None)
                    if value != None:
                        value = value.replace("&quot;", '"')
                        append_or_create(enums_dict, None, (name, value))
                else: # base != None
                    alias = child.attrib.get("alias", None)
                    if alias:
                        append_or_create(enums_dict, base, (name, alias))
                        continue
                    bitpos = child.attrib.get("bitpos", None)
                    if bitpos != None:
                        append_or_create(enums_dict, base, (name, "1<<%s" % bitpos))
                        continue
                    value = child.attrib.get("value", None)
                    if value != None:
                        append_or_create(enums_dict, base, (name, value))
                        continue

                    #we discarded other options, if we reach here, it should have "offset"
                    offset = child.attrib["offset"]
                    enum_ext_number = child.attrib.get("extnumber", None)
                    if enum_ext_number == None:
                        enum_ext_number = ext_number
                    ext_num = int(enum_ext_number) - 1
                    enum_value = 100000000 + (ext_num * 1000) + int(offset)
                    append_or_create(enums_dict, base, (name, enum_value))



def parse_commands(node):

    lines = []

    for command in node:
        assert(command.tag == "command")

        alias = command.attrib.get("alias", None)
        if alias != None:
            continue

        retval = None
        cmd_name = None

        params = []
        for tag in command:
            if tag.tag == "proto":
                for proto_tag in tag:
                    if proto_tag.tag == "type":
                        retval = get_type_from_node(proto_tag)
                    elif proto_tag.tag == "name":
                        cmd_name = proto_tag.text
            elif tag.tag == "param":
                param_name = None
                param_type = None
                for proto_tag in tag:
                    if proto_tag.tag == "type":
                        param_type = get_type_from_node(proto_tag)
                    elif proto_tag.tag == "name":
                        param_name = proto_tag.text
                params.append( (param_name, param_type) )

        lines.append("\t%s :: proc(" % cmd_name)
        for param in params:
            lines.append("\t\t%s: %s," % param)

        retval = retval.strip()
        if retval == "VOID":
            lines.append("\t) ---;\n")
        else:
            lines.append("\t) -> %s ---;\n" % retval)

    return "\n".join(lines)

def parse_enum(node):
    name = node.attrib["name"]

    if name == "API Constants":
        consts = []
        for child in node:
            assert(child.tag == "enum")
            name = child.attrib["name"]
            value = child.attrib.get("value", None)
            if value:
                if value.find("U") != -1:
                    value = "0"
                elif value[-1:] == "f":
                    value = value[:-1]
            alias = child.attrib.get("alias", None)
            if alias:
                value = alias
            consts.append((name, value))
        return (None, (consts))

    type = node.attrib.get("type", None)
    if type == None:
        return
    if type != "enum" and type != "bitmask":
        print("unhandled type: %s" % type)

    lines = []

    for entry in node:
        if entry.tag == "comment":
            continue
        if entry.tag == "unused":
            continue

        enum_name = entry.attrib["name"]
        enum_val = entry.attrib.get("value", None)


        if enum_val != None:
            lines.append((enum_name, enum_val))
        else:
            # enum_bitpos = entry.attrib["bitpos"]
            enum_bitpos = entry.attrib.get("bitpos", None)
            if enum_bitpos != None:
                lines.append((enum_name, "1<<%s" % enum_bitpos))
            else:
                enum_alias = entry.attrib["alias"]
                lines.append((enum_name, enum_alias))

    return name, lines

def parse_types(node):
    lines = []
    for type in node:
        if type.tag != "type":
            continue

        attrs = type.attrib
        cat = attrs.get("category", "NO_CATEGORY")

        result = None

        if cat == "NO_CATEGORY":
            req = attrs.get("requires")
            if req:
                name = attrs["name"]
                result = "%s :: distinct rawptr;" % name


        elif cat == "basetype":
            result = write_basetype(type)
        elif cat == "enum":
            alias = attrs.get("alias", None)
            if alias:
                result = "%s :: %s;" % (attrs["name"], alias)
        elif cat == "struct":
            result = write_struct(type, False)
        elif cat == "union":
            result = write_struct(type, True)
        elif cat == "handle":
            result = write_handle(type)
        elif cat == "funcpointer":
            result = write_funcpointer(type)
        elif cat == "bitmask":
            result = write_bitmask(type)

        if result:
            lines.append(result)

        #importantes:
        # bitmask
        # handle
        # enum
        # struct
    return "\n".join(lines)

BASE_TYPES = {
    "uint32_t": "u32",
    "uint64_t": "u64",
    "b32": "b32",
    "distinct rawptr": "distinct rawptr",
}

def write_basetype(tag):
    name = None
    type = "distinct rawptr"
    for child in tag:
        if child.tag == "type":
            type = child.text
        if child.tag == "name":
            name = child.text
    if name == "VkBool32":
        type = "b32";
    if name and type:
        return "%s :: %s;" % (name, BASE_TYPES[type])

def write_bitmask(tag):
    name = tag.attrib.get("name", None)
    if not name:
        for child in tag:
            if child.tag == "name":
                name = child.text
    assert(name)
    type = "VkFlags"
    alias = tag.attrib.get("alias", None)
    if alias:
        type = alias
    requires = tag.attrib.get("requires", None)
    if requires:
        type = requires

    return "%s :: %s;" % (name, type)

def write_funcpointer(tag):
    name = None
    params = []
    for child in tag:
        if child.tag == "name":
            name = child.text
        elif child.tag == "type":
            params.append(child)
    assert(name)

    retval = tag.text
    assert(retval[:7] == "typedef")
    retval = retval[8:]

    retval_end = retval.find("(")
    retval = retval[:retval_end]



    lines = []
    lines.append("%s :: proc (" % name);
    for param in params:

        stars = name.count('*')

        param_type = get_type_from_node(param)

        exclude = ' *\t\n,);'
        param_name = str.strip(param.tail, exclude)
        if param_name[-5:] == "const":
            param_name = param_name[:-5]
            param_name = str.strip(param_name, exclude)

        lines.append("\t%s: %s," % (param_name, param_type))

    retval = str.strip(retval)
    if retval == "void":
        lines.append(");")
    elif retval == "void*":
        lines.append(") -> rawptr;")
    else:
        lines.append(") -> %s;" % retval)

    return "\n".join(lines)

def write_handle(tag):
    name = None
    for child in tag:
        if child.tag == "name":
            name = child.text
            break
    if name != None:
        return "%s :: distinct rawptr;" % name

    name = tag.attrib["name"]
    alias = tag.attrib["alias"]
    return "%s :: %s;" % (name, alias)

def write_struct(struct_tag, is_union):

    output = ['\n']
    if is_union:
        output.append("%s :: struct #raw_union {" % struct_tag.attrib["name"])
    else:
        output.append("%s :: struct {" % struct_tag.attrib["name"])
    for member in struct_tag:
        if member.tag == "comment":
            continue
        assert(member.tag == "member")
        type = None
        name = None
        num = None
        for child in member:
            if child.tag == "comment":
                continue
            if child.tag == "name":
                name = child.text
            elif child.tag == "type":
                type = get_type_from_node(child)
            elif child.tag == "enum":
                num = child.text
            else:
                print(child.text)
        if num:
            type = "[%s]%s" % (num, type)
        output.append("\t%s: %s," % (name, type))
    output.append("}")

    return "\n".join(output)

MAPPED_TYPES = {
    "uint8_t": "u8",
    "uint16_t": "u16",
    "uint32_t": "u32",
    "uint64_t": "u64",
    "int8_t": "i8",
    "int16_t": "i16",
    "int32_t": "i32",
    "int64_t": "i64",
    "float": "f32",
    "double": "f64",
    "size_t": "u64",
    "void": "VOID",
    "char": "CHAR",
}

def get_type_from_node(in_node):
    type = in_node.text

    if type in MAPPED_TYPES:
        type = MAPPED_TYPES[type]

    if in_node.tail:
        num_stars = in_node.tail.count("*")
        for i in range(num_stars):
            type = "^%s" % type

    type = type.replace("^VOID", "rawptr")
    type = type.replace("^CHAR", "cstring")
    type = type.replace("CHAR", "u8")

    return type

main()
