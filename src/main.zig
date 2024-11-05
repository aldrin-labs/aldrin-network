const std = @import("std");
const vm = @import("vm.zig");
const instructions = @import("instructions.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var program = std.ArrayList(instructions.Instruction).init(allocator);
    defer program.deinit();

    try program.append(.{ .Load = .{ .reg = 0, .value = 100 } });
    try program.append(.{ .Load = .{ .reg = 1, .value = 10 } });
    try program.append(.{ .Load = .{ .reg = 2, .value = 1 } });
    try program.append(.{ .PlaceOrderOptimized = .{
        .price_reg = 0,
        .amount_reg = 1,
        .id_reg = 2,
    } });

    var bulk_vm = try vm.BulkBookVM.init(allocator, program.items, 8);
    defer bulk_vm.deinit();

    std.debug.print("Initial state:\n", .{});
    std.debug.print("Registers: {any}\n", .{bulk_vm.registers});
    std.debug.print("Best bid: {}\n", .{@atomicLoad(u64, &bulk_vm.best_bid, .Monotonic)});
    std.debug.print("Best ask: {}\n", .{@atomicLoad(u64, &bulk_vm.best_ask, .Monotonic)});

    try bulk_vm.run();

    std.debug.print("\nFinal state:\n", .{});
    std.debug.print("Registers: {any}\n", .{bulk_vm.registers});
    std.debug.print("Best bid: {}\n", .{@atomicLoad(u64, &bulk_vm.best_bid, .Monotonic)});
    std.debug.print("Best ask: {}\n", .{@atomicLoad(u64, &bulk_vm.best_ask, .Monotonic)});

    const shard = bulk_vm.orderbook.priceToShard(100);
    std.debug.print("Orders in shard {}: {}\n", .{ shard, bulk_vm.orderbook.shards[shard].count() });
}