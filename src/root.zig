//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Upper: []const u8 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const LowerStart = Upper.len;
pub const Lower: []const u8 = "abcdefghijklmnopqrstuvwxyz";
const NumberStart = Upper.len + Lower.len;
pub const Numbers: []const u8 = "0123456789";
pub const Symbols: []const u8 = "+/";
pub const Table: []const u8 = Upper ++ Lower ++ Numbers ++ Symbols;

fn encodeByte(
    byte: u8,
    output: *[4]u8
) void {
    const first_table_index = byte >> 2;
    output[0] = Table[first_table_index];

    const second_table_index = (byte << 4) & 0x3f;
    output[1] = Table[second_table_index];
    output[2] = '=';
    output[3] = '=';
}

fn encode2BChunk(
    byte_chunk: *const [2]u8,
    output: *[4]u8
) void {
    const chunk: u16 = std.mem.readInt(u16, byte_chunk, .big);

    const first_table_index = chunk >> 10;
    output[0] = Table[first_table_index];

    const second_table_index = (chunk >> 4) & 0x3f;
    output[1] = Table[second_table_index];

    const third_table_index = (chunk << 2) & 0x3f;
    output[2] = Table[third_table_index];
    output[3] = '=';
}

fn encode3BChunk(
    byte_chunk: *const [3]u8,
    output: *[4]u8
) void {
    const chunk: u32 = (@as(u32, byte_chunk[0]) << 16) |
                    (@as(u32, byte_chunk[1]) << 8) |
                    (@as(u32, byte_chunk[2]));

    const first_table_index = (chunk >> 18) & 0x3f;
    output[0] = Table[first_table_index];

    const second_table_index = (chunk >> 12) & 0x3f;
    output[1] = Table[second_table_index];

    const third_table_index = (chunk >> 6) & 0x3f;
    output[2] = Table[third_table_index];

    const fourth_table_index = (chunk) & 0x3f;
    output[3] = Table[fourth_table_index];
}

pub fn encode(input: []const u8, allocator: Allocator) Allocator.Error![]u8 {
    if (input.len == 0) return "";

    const complete_packs: usize = input.len / 3;
    const rest: usize = input.len % 3;
    const extra_pack: usize = if(rest == 0) 0 else 1;

    const output_size: usize = (complete_packs + extra_pack) * 4;
    const output: []u8 = try allocator.alloc(u8,output_size);

    for (0..complete_packs) |pack_number| {
        const base_input_index = 3 * pack_number;
        const base_output_index = 4 * pack_number;
        encode3BChunk(
            input[base_input_index..][0..3],
            output[base_output_index..][0..4]
        );
    }

    const base_input_index = 3 * complete_packs;
    const base_output_index = 4 * complete_packs;

    switch (rest) {
        1 => encodeByte(
            input[base_input_index], 
            output[base_output_index..][0..4]
        ),
        2 => encode2BChunk(
            input[base_input_index..][0..2],
            output[base_output_index..][0..4]
        ),
        0 => {},
        else => unreachable
    }
    return output;
}

fn calcBytesToSubtract(input: []const u8) usize {
    return if (input[input.len - 2] == '=') 2 
        else if (input[input.len - 1] == '=') 1 
        else 0;
}

fn decodeChar(char: u8) u24 {
    if (char >= 'a') return @as(u24, char - 'a' + @as(u24,LowerStart));
    if (char >= 'A') return @as(u24, char - 'A');
    if (char >= '0') return @as(u24, char - '0' + @as(u24,NumberStart));
    if (char == '+') return @as(u24,62);
    return @as(u24,63);
}

fn decode2CharChunk(
    char_chunk: *const [2]u8,
    output: *u8
) void {
    const byte_chunk: u24 = decodeChar(char_chunk[0]) << 6 |
                            decodeChar(char_chunk[1]);
    output.* = @intCast(byte_chunk >> 4);
}

fn decode3CharChunk(
    char_chunk: *const [3]u8,
    output: *[2]u8
) void {
    const byte_chunk: u24 = decodeChar(char_chunk[0]) << 12 |
                            decodeChar(char_chunk[1]) << 6 |
                            decodeChar(char_chunk[2]);
    output[0] = @intCast(byte_chunk >> 10);
    output[1] = @intCast((byte_chunk >> 2) & 0xff);
}

fn decode4CharChunk(
    char_chunk: *const [4]u8,
    output: *[3]u8
) void {
    const byte_chunk: u24 = decodeChar(char_chunk[0]) << 18 |
                            decodeChar(char_chunk[1]) << 12 |
                            decodeChar(char_chunk[2]) << 6 |
                            decodeChar(char_chunk[3]);
    output[0] = @intCast(byte_chunk >> 16);
    output[1] = @intCast((byte_chunk >> 8) & 0xff);
    output[2] = @intCast(byte_chunk & 0xff);
}

pub fn decode(input: []const u8, allocator: Allocator) Allocator.Error![]u8 {
    if (input.len == 0) return "";

    const packs: usize = input.len / 4;

    const bytes_to_subtract = calcBytesToSubtract(input);

    const output_size: usize = (packs * 3) - bytes_to_subtract;
    const output: []u8 = try allocator.alloc(u8,output_size);

    for (0..packs-1) |pack_number| {
        const base_input_index = 4 * pack_number;
        const base_output_index = 3 * pack_number;
        decode4CharChunk(
            input[base_input_index..][0..4],
            output[base_output_index..][0..3]
        );
    }

    const base_input_index = 4 * (packs - 1);
    const base_output_index = 3 * (packs - 1);

    switch (bytes_to_subtract) {
        0 => decode4CharChunk(
            input[base_input_index..][0..4],
            output[base_output_index..][0..3]
        ),
        1 => decode3CharChunk(
            input[base_input_index..][0..3],
            output[base_output_index..][0..2]
        ),
        2 => decode2CharChunk(
            input[base_input_index..][0..2],
            &output[base_output_index]
        ),
        else => unreachable
    }

    return output;
}