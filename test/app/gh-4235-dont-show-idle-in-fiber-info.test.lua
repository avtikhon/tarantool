test_run = require('test_run').new()
netbox = require('net.box')
fiber = require('fiber')

test_run:cmd('setopt delimiter ";"')
function count_idle()
    local idle = 0
    for fid, info in pairs(fiber.info()) do
        if info.backtrace == nil then
            idle = idle + 1
        end
    end
    return idle
end;

cnt = 0;
idle = 0;
done = false;
function yielder()
    cnt = cnt + 1
    while not done do
        fiber.yield()
    end
    cnt = cnt - 1
end;
test_run:cmd('setopt delimiter ""');

box.schema.user.grant('guest', 'execute', 'universe')
conn = netbox.connect(box.cfg.listen)

prev_idle = count_idle()

n = 100
-- We need to fill cbus with multiple requests to make
-- fiber pool in TX thread expand to at least `n` fibers.
for i = 1, n do conn:call('yielder', nil, {is_async = true}) end

while cnt < n do fiber.yield() end
done = true
while cnt > 0 do fiber.yield() end

-- Most of the fibers created by `conn:call` must be in the IDLE state
assert(count_idle() + prev_idle >= n)

conn:close()
box.schema.user.revoke('guest', 'execute', 'universe')
