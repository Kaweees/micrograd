//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const micrograd = @import("micrograd");
const zbench = @import("zbench");

/// Write the computational graph to a Graphviz file
pub fn draw_graph(comptime T: type, graph: *micrograd.engine.Value(T), name: []const u8, writer: anytype) !void {
    const file = try std.fs.cwd().createFile(name, .{});
    defer file.close();
    const file_writer = file.writer();
    try graph.draw_dot(file_writer, std.heap.page_allocator);

    try writer.print("Computational graph written to {s}\n", .{name});
    try writer.print("You can visualize it by running: dot -Tpng {s} -o {s}\n", .{ name, name });
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Initialize the arena allocator
    micrograd.engine.Value(f32).init(std.heap.page_allocator);
    defer micrograd.engine.Value(f32).deinit();

    // Create a more complex computational graph
    const a = micrograd.engine.Value(f32).new(2.0);
    const b = micrograd.engine.Value(f32).new(-3.0);
    const c = micrograd.engine.Value(f32).new(10.0);
    const d = a.mul(b);
    // Perform operations: e = (a * b) + c
    const e = d.add(c);
    const f = micrograd.engine.Value(f32).new(-2.0);
    const g = f.mul(e);

    // Write the computational graph to a Graphviz file
    const file = try std.fs.cwd().createFile("graph.dot", .{});
    defer file.close();

    try stdout.print("d.data: {}\n", .{d.data});
    try stdout.print("d.grad: {}\n", .{d.grad});

    try d.backwardPass(std.heap.page_allocator);

    try stdout.print("d.data: {}\n", .{d.data});
    try stdout.print("d.grad: {}\n", .{d.grad});

    const file_writer = file.writer();
    try g.draw_dot(file_writer, std.heap.page_allocator);

    try stdout.print("Computational graph written to graph.dot\n", .{});
    try stdout.print("You can visualize it by running: dot -Tpng graph.dot -o graph.png\n", .{});

    // Write the computational graph to a Graphviz file
    try draw_graph(f32, g, "graph.dot", stdout);

    // const neuron_f32 = try lib.nn.Neuron(f32).init(std.heap.page_allocator, 3);
    // const neuron_f64 = try lib.nn.Neuron(f64).init(std.heap.page_allocator, 5);
    // const neuron_i32 = try lib.nn.Neuron(i32).init(std.heap.page_allocator, 2);

    // try draw_graph(f32, a, "graph.dot", stdout);
    // try draw_graph(f64, a, "graph.dot", stdout);
    // try draw_graph(i32, a, "graph.dot", stdout);

    try bw.flush(); // Don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), micrograd.add(100, 50));
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
