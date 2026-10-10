# APB3 Hardware Timer (Verilog)

A synthesizable, single-clock APB3-compatible timer peripheral with a 16-bit prescaler, 32-bit auto-reload counter, one-shot/periodic operation, and sticky interrupt status.

## Structure
- `rtl/apb_timer.v`: synthesizable APB timer slave
- `tb/tb_apb_timer.sv`: self-checking directed testbench

## Register map
| Offset | Register | Description |
|---|---|---|
| 0x00 | CTRL | bit 0 START (write-one); bit 1 MODE (0 one-shot, 1 periodic); bit 2 STOP (write-one); bit 3 BUSY (RO); bit 4 DONE (RO) |
| 0x04 | PSC | 16-bit prescaler (RW) |
| 0x08 | ARR | 32-bit auto-reload (RW) |
| 0x0C | CNT | Current counter (RO) |
| 0x10 | IRQ_ENABLE | bit 0 mask (RW) |
| 0x14 | IRQ_STATUS | bit 0 pending (read; write-one-to-clear) |

Timer period = `(PSC+1)*(ARR+1)` PCLK cycles when configuration is stable. `irq` is level-sensitive. Simultaneous expiry overrides IRQ clear.

## Simulation
```sh
iverilog -g2012 -s tb_apb_timer -o sim.out rtl/apb_timer.v tb/tb_apb_timer.sv
vvp sim.out
```
View `apb_timer.vcd` in GTKWave. The testbench is directed and self-checking but execution and synthesis results have not yet been independently confirmed.

## Limitations / future work
- APB3-compatible zero-wait-state slave; 8-bit register offset and 32-bit bus.
- Configure PSC/ARR while stopped; changes during RUN apply immediately.
- All timer/bus logic shares PCLK (no CDC).
- Each CTRL write also updates MODE, including STOP commands.
- Add protocol assertions, coverage, scoreboard testing, and synthesis/timing checks.
