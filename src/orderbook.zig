const std = @import("std");

pub const CacheAlignedOrder = struct {
    price: u64,
    amount: u64,
    id: u64,
    padding: [40]u8,

    pub fn init(price: u64, amount: u64, id: u64) CacheAlignedOrder {
        return .{
            .price = price,
            .amount = amount,
            .id = id,
            .padding = [_]u8{0} ** 40,
        };
    }
};

fn orderCompare(_: void, a: u64, b: u64) std.math.Order {
    return std.math.order(a, b);
}

pub const OrderTreeMap = std.TreeMap(u64, CacheAlignedOrder, void, orderCompare);

pub const ShardedOrderbook = struct {
    shards: []OrderTreeMap,
    shard_count: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, shard_count: usize) !ShardedOrderbook {
        var shards = try allocator.alloc(OrderTreeMap, shard_count);
        for (shards) |*shard| {
            shard.* = OrderTreeMap.init(allocator, {});
        }

        return ShardedOrderbook{
            .shards = shards,
            .shard_count = shard_count,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ShardedOrderbook) void {
        for (self.shards) |*shard| {
            var it = shard.iterator();
            while (it.next()) |node| {
                self.allocator.destroy(node);
            }
            shard.deinit();
        }
        self.allocator.free(self.shards);
    }

    pub fn placeOrder(self: *ShardedOrderbook, price: u64, amount: u64, id: u64) !void {
        const shard_index = self.priceToShard(price);
        const order = CacheAlignedOrder.init(price, amount, id);
        try self.shards[shard_index].put(price, order);
    }

    pub fn getBestBid(self: *const ShardedOrderbook) ?u64 {
        var best_bid: ?u64 = null;
        for (self.shards) |shard| {
            if (shard.count() > 0) {
                if (shard.iterator().last()) |entry| {
                    const price = entry.key_ptr.*;
                    best_bid = if (best_bid) |current_best| @max(current_best, price) else price;
                }
            }
        }
        return best_bid;
    }

    pub fn getBestAsk(self: *const ShardedOrderbook) ?u64 {
        var best_ask: ?u64 = null;
        for (self.shards) |shard| {
            if (shard.count() > 0) {
                if (shard.iterator().first()) |entry| {
                    const price = entry.key_ptr.*;
                    best_ask = if (best_ask) |current_best| @min(current_best, price) else price;
                }
            }
        }
        return best_ask;
    }

    pub fn getOrdersInRange(self: *const ShardedOrderbook, start_price: u64, end_price: u64, shard_index: usize) u64 {
        var total_amount: u64 = 0;
        var it = self.shards[shard_index].iterator();

        while (it.next()) |entry| {
            const price = entry.key_ptr.*;
            if (price >= start_price and price <= end_price) {
                total_amount += entry.value_ptr.amount;
            } else if (price > end_price) {
                break; // Early exit due to ordered nature
            }
        }
        return total_amount;
    }

    pub fn priceToShard(self: *const ShardedOrderbook, price: u64) usize {
        return @intCast(usize, price % @intCast(u64, self.shard_count));
    }
};
