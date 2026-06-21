const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const base64 = @import("base64");

const build_options = @import("build_options"); 

pub const std_options: std.Options = .{
    .log_level = @enumFromInt(@intFromEnum(build_options.log_level)),
};

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
    const args = init.minimal.args.toSlice(allocator) catch |err| {
        std.log.err("Could not get console args.\n{}",.{err});
        return;
    };
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    var read_buffer: []u8 = undefined;
    var function: *const fn([]const u8, Allocator) Allocator.Error![]u8 = undefined;
    var message: []const u8 = undefined;

    const execType = defineExecType(args);
    switch (execType) {
        .encode => {
            function = base64.encode;
            message = "Encode";
            // multiple of 3 to match encoding blocks
            read_buffer = try allocator.alloc(u8, 4095);
        },
        .decode => {
            function = base64.decode;
            message = "Decode";
            // multiple of 4 to match decoding blocks
            read_buffer = try allocator.alloc(u8, 4096);
        },
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

    // open file and get reader
    const file = cwd.openFile(io, args[2], .{}) catch |err| {
        std.log.err("Could not open input file {s}\n{}", .{args[1], err});
        return;
    };
    defer file.close(io);
    var file_reader = file.reader(io, &.{});
    const reader = &file_reader.interface;

    // create file and get writer
    const output_file = cwd.createFile(io, args[3], .{}) catch |err| {
        std.log.err("Could not create output file {s}\n{}", .{args[3], err});
        return;
    };
    defer output_file.close(io);
    var file_writer = output_file.writer(io, &.{});
    const writer = &file_writer.interface;

    var backing: [16][]u8 = undefined;
    var queue: std.Io.Queue([]u8) = .init(&backing);
    var group: std.Io.Group = .init;

    group.concurrent(io, worker, .{
        io,
        &queue,
        reader,
        read_buffer,
        function,
        message,
        allocator
    }) catch |err| {
        std.log.err("Error creating worker.\n{}",.{err});
        return;       
    };
    
    group.async(io, saver, .{
        io,
        &queue,
        writer
    });

    group.await(io) catch |err| {
        std.log.err("Error during await.\n{}",.{err});
        return;
    };

    const elapsed = start.untilNow(io, .awake);

    std.log.warn("\nElapsed time: {}\n",.{elapsed});
}

fn worker(
    io: std.Io,
    queue: *std.Io.Queue([]u8),
    reader: *std.Io.Reader,
    read_buffer: []u8,
    function: *const fn([]const u8, Allocator) Allocator.Error![]u8,
    message: []const u8,
    allocator: Allocator
) void {
    while (true) {
        const len = reader.readSliceShort(read_buffer) catch |err| {
            std.log.err("Could not read from file\n{}",.{err});
            return;
        };
        const output = function(read_buffer[0..len], allocator) catch |err| {
            std.log.err("Could not {s}.\n{}",.{message, err});
            return;
        };
        std.log.info("{s}d:\n{s}",.{message, output});
        queue.putOne(io, output) catch |err| {
            std.log.err("Unable to enqueue {s} output.\n{}",.{message, err});
        };
        if (len < read_buffer.len or len == 0) break;
    }
    queue.close(io);
}

fn saver(
    io: std.Io,
    queue: *std.Io.Queue([]u8),
    writer: *std.Io.Writer
    // read_buffer: []u8,
) void {
    while (true) {
        const output = queue.getOne(io) catch |err| switch (err) {
            error.Closed => break,
            else => {
                std.log.err("Could not get output from queue.\n{}",.{err});
                return;
            },
        };
        _ = writer.write(output) catch |err| {
            std.log.err("Could not output the result.\n{}",.{err});
            return;
        };
    }
}
