//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const kiwigrad = @import("kiwigrad");
const zbench = @import("zbench");

/// Write the computational graph to a Graphviz file
pub fn draw_graph(comptime T: type, graph: *kiwigrad.engine.Value(T), name: []const u8, writer: anytype) !void {
    const dot_name = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.dot", .{name});
    defer std.heap.page_allocator.free(dot_name);
    const png_name = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.png", .{name});
    defer std.heap.page_allocator.free(png_name);

    const file = try std.fs.cwd().createFile(dot_name, .{});
    defer file.close();
    const file_writer = file.writer();
    try graph.draw_dot(file_writer, std.heap.page_allocator);

    try writer.print("Computational graph written to {s}\n", .{dot_name});
    try writer.print("You can visualize it by running: dot -Tpng {s} -o {s}\n", .{ dot_name, png_name });
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    // Initialize the arena allocator
    kiwigrad.engine.Value(f64).init(std.heap.page_allocator);
    defer kiwigrad.engine.Value(f64).deinit();
    // Initialize the neuron allocator
    kiwigrad.nn.Neuron(f64).init(std.heap.page_allocator);
    defer kiwigrad.nn.Neuron(f64).deinit();
    const n_f64 = kiwigrad.nn.Neuron(f64).new(2);
    // Create sample input data
    var input_data = [_]*kiwigrad.engine.Value(f64){
        kiwigrad.engine.Value(f64).new(1.0),
        kiwigrad.engine.Value(f64).new(2.0),
    };
    const output = n_f64.forward(input_data[0..]);
    try draw_graph(f64, output, "n_f64", stdout);
    try bw.flush(); // Don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), kiwigrad.add(100, 50));
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
