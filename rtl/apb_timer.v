// APB3 timer: 32-bit up-counter, 16-bit prescaler, periodic/one-shot, IRQ.
module apb_timer (
    input wire PCLK, PRESETn, PSEL, PENABLE, PWRITE,
    input wire [7:0] PADDR,
    input wire [31:0] PWDATA,
    output reg [31:0] PRDATA,
    output wire PREADY, PSLVERR, irq,
    output reg tick
);
    localparam [7:0] CTRL=8'h00, PSC=8'h04, ARR=8'h08,
                     CNT=8'h0c, IEN=8'h10, IST=8'h14;
    localparam [1:0] IDLE=2'd0, RUN=2'd1, DONE=2'd2;
    reg [1:0] state;
    reg mode_reg, irq_enable_reg, irq_status_reg;
    reg [15:0] psc_reg, psc_count;
    reg [31:0] arr_reg, count;
    wire addr_valid = PADDR==CTRL || PADDR==PSC || PADDR==ARR ||
                      PADDR==CNT || PADDR==IEN || PADDR==IST;
    assign PREADY = 1'b1;
    assign PSLVERR = PSEL && PENABLE && (!addr_valid || (PWRITE && PADDR==CNT));
    wire wr = PSEL && PENABLE && PWRITE && !PSLVERR;
    wire start_cmd = wr && PADDR==CTRL && PWDATA[0];
    wire stop_cmd = wr && PADDR==CTRL && PWDATA[2];
    wire irq_clear = wr && PADDR==IST && PWDATA[0];
    assign irq = irq_enable_reg && irq_status_reg;
    always @* begin
        PRDATA = 32'd0;
        case (PADDR)
            CTRL: PRDATA = {27'd0, state==DONE, state==RUN, 1'b0, mode_reg, 1'b0};
            PSC: PRDATA = {16'd0, psc_reg};
            ARR: PRDATA = arr_reg;
            CNT: PRDATA = count;
            IEN: PRDATA = {31'd0, irq_enable_reg};
            IST: PRDATA = {31'd0, irq_status_reg};
            default: PRDATA = 0;
        endcase
    end
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            mode_reg <= 0;
            psc_reg <= 0;
            arr_reg <= 0;
            irq_enable_reg <= 0;
        end else if (wr) begin
            case (PADDR)
                CTRL: mode_reg <= PWDATA[1];
                PSC: psc_reg <= PWDATA[15:0];
                ARR: arr_reg <= PWDATA;
                IEN: irq_enable_reg <= PWDATA[0];
                default: ;
            endcase
        end
    end
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            state <= IDLE;
            psc_count <= 0;
            count <= 0;
            tick <= 0;
            irq_status_reg <= 0;
        end else begin
            tick <= 0;
            if (irq_clear) irq_status_reg <= 0;
            if (stop_cmd) begin
                state <= IDLE;
                psc_count <= 0;
                count <= 0;
            end else if (start_cmd && state!=RUN) begin
                state <= RUN;
                psc_count <= 0;
                count <= 0;
            end else if (state==RUN) begin
                if (psc_count >= psc_reg) begin
                    psc_count <= 0;
                    if (count >= arr_reg) begin
                        count <= 0;
                        tick <= 1;
                        irq_status_reg <= 1;
                        if (!mode_reg) state <= DONE;
                    end else count <= count + 1'b1;
                end else psc_count <= psc_count + 1'b1;
            end
        end
    end
endmodule
