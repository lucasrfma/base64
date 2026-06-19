const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const base64 = @import("base64");

const ExecutionType = enum {
    help,
    encode,
    decode,
    invalid,
};

fn defineExecType(args: []const []const u8) ExecutionType {
    if (args.len == 2 and
        std.mem.eql(u8, args[1], "-h") or std.mem.eql(u8, args[1], "help")
    ) {
        return ExecutionType.help;
    }

    if (args.len == 4) {
        if(std.mem.eql(u8, args[1], "-e") or std.mem.eql(u8, args[1], "encode")) {

            return ExecutionType.encode;
        }
        if (std.mem.eql(u8, args[1], "-d") or std.mem.eql(u8, args[1], "decode")) {

            return ExecutionType.decode;
        }
    }

    return ExecutionType.invalid;
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    // get allocator interface
    const allocator = arena.allocator();

    const io = init.io;
    const start = std.Io.Clock.awake.now(io);

    // get console args
    const args = init.minimal.args.toSlice(allocator) catch {
        std.log.err("Could not get console args =(",.{});
        return;
    };
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }
    const execType = defineExecType(args);

    switch (execType) {
        .encode,
        .decode => {},
        .help => {
            std.log.info("Print help.",.{});
            return;
        },
        .invalid => {
            std.log.info("Bad arguments, also print help.", .{});
            return;
        },
    }
    
    const cwd = std.Io.Dir.cwd();
    const outputFile = cwd.createFile(io, args[3], .{}) catch {
        std.log.err("Could not create output file", .{});
        return;
    };
    defer outputFile.close(io);
    var file_writer = outputFile.writer(io, &.{});
    const writer = &file_writer.interface;
    
    // Get file reader
    const file = cwd.openFile(io, args[2], .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.log.err("Could not find input file {s}", .{args[1]});
            return;
        },
        error.AccessDenied => {
            std.log.err("Access denied to input file {s}", .{args[1]});
            return;
        },
        else => {
            std.log.err("Could not open input file {s}", .{args[1]});
            return;
        }
    };
    defer file.close(io);
    var file_reader = file.reader(io, &.{});
    const reader = &file_reader.interface;

    var read_buffer: []u8 = undefined;

    var function: *const fn([]const u8, Allocator) Allocator.Error![]u8 = undefined;
    var message: []const u8 = undefined;
    switch (execType) {
        .encode => {
            function = base64.encode;
            message = "Encode";
            read_buffer = try allocator.alloc(u8, 4095);
        },
        .decode => {
            function = base64.decode;
            message = "Decode";
            read_buffer = try allocator.alloc(u8, 4096);
        },
        else => unreachable
    }

    while (true) {
        const len = reader.readSliceShort(read_buffer) catch {
            std.log.err("Could not read from file",.{});
            return;
        };
        const output = function(read_buffer[0..len], allocator) catch {
            std.log.err("Could not {s}.",.{message});
            return;
        };
        std.log.info("{s}d:\n{s}",.{message, output});
        _ = writer.write(output) catch {
            std.log.err("Could not output the result.",.{});
            return;
        };
        if (len < read_buffer.len or len == 0) break;
    }

    const elapsed = start.untilNow(io, .awake);

    std.log.info("\nElapsed time: {}\n",.{elapsed});
}
