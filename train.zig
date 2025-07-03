//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("micrograd");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Create a more complex computational graph
    var a = lib.engine.Value(f32).init(2.0, null, null, "a");
    var b = lib.engine.Value(f32).init(-3.0, null, null, "b");
    var c = lib.engine.Value(f32).init(10.0, null, null, "c");
    var d = try a.mul(&b, std.heap.page_allocator, "d");
    // Perform operations: e = (a * b) + c
    var e = try d.add(&c, std.heap.page_allocator, "e");
    var f = lib.engine.Value(f32).init(-2.0, null, null, "f");
    var g = try f.mul(&e, std.heap.page_allocator, "g");

    // Write the computational graph to a Graphviz file
    const file = try std.fs.cwd().createFile("graph.dot", .{});
    defer file.close();

    const file_writer = file.writer();
    try g.draw_dot(file_writer, std.heap.page_allocator);

    try stdout.print("Computational graph written to graph.dot\n", .{});
    try stdout.print("You can visualize it by running: dot -Tpng graph.dot -o graph.png\n", .{});

    try bw.flush(); // Don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
