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
    if (args.len == 2) {
        if (std.mem.eql(u8, args[1], "-h") or std.mem.eql(u8, args[1], "help")) {
            return ExecutionType.help;
        }
        return ExecutionType.encode;
    }

    if (args.len >= 3) {
        return ExecutionType.decode;
    }

    return ExecutionType.invalid;
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    // get allocator interface
    const allocator = arena.allocator();

    const io = init.io;
    // Get stdout Writer
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;
    defer stdout_writer.flush() catch {}; // Don't forget to flush!

    // get console args
    const args = init.minimal.args.toSlice(allocator) catch {
        std.log.err("Could not get console args =(",.{});
        return;
    };
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }
    const execType = defineExecType(args);

    var inputFile: []const u8 = undefined;
    // var outputFile: []u8 = undefined;
    switch (execType) {
        .encode => {
            inputFile = args[1];
            // _ = outputFile;
        },
        else => {
            return;
            // _ = inputFile;
            // _ = outputFile;
        }
    }

    // Get file reader
    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(io, inputFile, .{}) catch {
        std.log.err("Could not open file =(", .{});
        return;
    };
    defer file.close(io);
    var file_reader = file.reader(io, &.{});
    const reader = &file_reader.interface;

    const start = std.Io.Clock.awake.now(io);

    // multiple of 3, since we encode in triplets.
    var read_buffer: [2100]u8 = undefined;

    std.log.info("Output Data: \n",.{});
    while (true) {
        const len = reader.readSliceShort(&read_buffer) catch {
            std.log.err("Could not read from file =(",.{});
            return;
        };
        const output = base64.encode(read_buffer[0..len], allocator) catch {
            std.log.err("Could not encode =(",.{});
            return;
        };
        try stdout_writer.print("{s}",.{output});
        if (len < read_buffer.len or len == 0) break;
    }

    const elapsed = start.untilNow(io, .awake);

    std.log.info("\nElapsed time: {}\n",.{elapsed});
}
