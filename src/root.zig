//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const upper: []const u8 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const lowerStart = upper.len;
pub const lower: []const u8 = "abcdefghijklmnopqrstuvwxyz";
const numberStart = upper.len + lower.len;
pub const numbers: []const u8 = "0123456789";
pub const symbols: []const u8 = "+/";
pub const table: []const u8 = upper ++ lower ++ numbers ++ symbols;

fn encodeByte(
    byte: u8,
    output: *[4]u8
) void {
    const firstTableIndex = byte >> 2;
    output[0] = table[firstTableIndex];

    const secondTableIndex = (byte << 4) & 0x3f;
    output[1] = table[secondTableIndex];
    output[2] = '=';
    output[3] = '=';
}

fn encode2BChunk(
    byte_chunk: *const [2]u8,
    output: *[4]u8
) void {
    const chunk: u16 = std.mem.readInt(u16, byte_chunk, .big);

    const firstTableIndex = chunk >> 10;
    output[0] = table[firstTableIndex];

    const secondTableIndex = (chunk >> 4) & 0x3f;
    output[1] = table[secondTableIndex];

    const thirdTableIndex = (chunk << 2) & 0x3f;
    output[2] = table[thirdTableIndex];
    output[3] = '=';
}

// calling a 6bit pack a byt... 8 -> 6, 4characters -> 3
// const byt = packed struct(u32){
//     _3: u6,
//     _2: u6,
//     _1: u6,
//     _0: u6,
// };

fn encode3BChunk(
    byte_chunk: *const [3]u8,
    output: *[4]u8
) void {
    const chunk: u32 = (@as(u32, byte_chunk[0]) << 16) |
                    (@as(u32, byte_chunk[1]) << 8) |
                    (@as(u32, byte_chunk[2]));

    const firstTableIndex = (chunk >> 18) & 0x3f;
    output[0] = table[firstTableIndex];

    const secondTableIndex = (chunk >> 12) & 0x3f;
    output[1] = table[secondTableIndex];

    const thirdTableIndex = (chunk >> 6) & 0x3f;
    output[2] = table[thirdTableIndex];

    const fourthTableIndex = (chunk) & 0x3f;
    output[3] = table[fourthTableIndex];
}

pub fn encode(input: []const u8, allocator: Allocator) Allocator.Error![]u8 {
    if (input.len == 0) return "";

    const completePacks: usize = input.len / 3;
    const rest: usize = input.len % 3;
    const extraPack: usize = if(rest == 0) 0 else 1;

    const outputSize: usize = (completePacks + extraPack) * 4;
    const output: []u8 = try allocator.alloc(u8,outputSize);

    for (0..completePacks) |packNumber| {
        const baseInputIndex = 3 * packNumber;
        const baseOutputIndex = 4 * packNumber;
        encode3BChunk(
            input[baseInputIndex..][0..3],
            output[baseOutputIndex..][0..4]
        );
    }

    const baseInputIndex = 3 * completePacks;
    const baseOutputIndex = 4 * completePacks;

    switch (rest) {
        1 => encodeByte(
            input[baseInputIndex], 
            output[baseOutputIndex..][0..4]
        ),
        2 => encode2BChunk(
            input[baseInputIndex..][0..2],
            output[baseOutputIndex..][0..4]
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
    if (char >= 'a') return @as(u24, char - 'a' + @as(u24,lowerStart));
    if (char >= 'A') return @as(u24, char - 'A');
    if (char >= '0') return @as(u24, char - '0' + @as(u24,numberStart));
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

    const bytesToSubtract = calcBytesToSubtract(input);

    const outputSize: usize = (packs * 3) - bytesToSubtract;
    const output: []u8 = try allocator.alloc(u8,outputSize);

    for (0..packs-1) |packNumber| {
        const baseInputIndex = 4 * packNumber;
        const baseOutputIndex = 3 * packNumber;
        decode4CharChunk(
            input[baseInputIndex..][0..4],
            output[baseOutputIndex..][0..3]
        );
    }

    const baseInputIndex = 4 * (packs - 1);
    const baseOutputIndex = 3 * (packs - 1);

    switch (bytesToSubtract) {
        0 => decode4CharChunk(
            input[baseInputIndex..][0..4],
            output[baseOutputIndex..][0..3]
        ),
        1 => decode3CharChunk(
            input[baseInputIndex..][0..3],
            output[baseOutputIndex..][0..2]
        ),
        2 => decode2CharChunk(
            input[baseInputIndex..][0..2],
            &output[baseOutputIndex]
        ),
        else => unreachable
    }

    return output;
}