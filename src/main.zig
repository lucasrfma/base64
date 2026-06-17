const std = @import("std");
const Io = std.Io;

const base64 = @import("base64");

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // get allocator interface
    const allocator = arena.allocator();
    
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;
    defer stdout_writer.flush() catch {}; // Don't forget to flush!

    var stderr_buffer: [256]u8 = undefined;
    var stderr_file_writer = Io.File.stderr().writer(io, &stderr_buffer);
    const stderr_writer = &stderr_file_writer.interface;
    defer stderr_writer.flush() catch {};

    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(io, "testfile.txt", .{}) catch {
        try stdout_writer.print("Could not open file =(", .{});
        return;
    };
    defer file.close(io);

    var file_reader = file.reader(io, &.{});
    const reader = &file_reader.interface;

    const start = std.Io.Clock.awake.now(io);

    // multiple of 3, since we encode in triplets.
    var read_buffer: [2100]u8 = undefined;

    try stdout_writer.print("Output Data: \n",.{});
    while (true) {
        const len = reader.readSliceShort(&read_buffer) catch {
            try stderr_writer.print("Could not read from file =(",.{});
            return;
        };
        const output = base64.encode(read_buffer[0..len], allocator) catch {
            try stderr_writer.print("Could not encode =(",.{});
            return;
        };
        try stdout_writer.print("{s}",.{output});
        if (len < read_buffer.len or len == 0) break;
    }

    // const decoded = base64.decode(output, allocator) catch "Could not decode =(";
    const elapsed = start.untilNow(io, .awake);

    // try stdout_writer.print("Input Data: {s}\n",.{input});
    // try stdout_writer.print("Redecoded Data: {s}\n",.{decoded});
    // if (std.mem.eql(u8, input, decoded)) {
    //     try stdout_writer.print("Encode Decode Successful\n",.{});
    // } else {
    //     try stdout_writer.print("Encode Decode Incorrect\n",.{});
    // }
    try stdout_writer.print("\nElapsed time: {}\n",.{elapsed});
}
