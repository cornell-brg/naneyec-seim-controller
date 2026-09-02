// ================================================================
//
// Shared state definitions for the NanEyeC controller and its control unit.
//
// ================================================================

`ifndef _NANEYE_CTL_STATE_PKG_SV_
`define _NANEYE_CTL_STATE_PKG_SV_

package naneye_ctl_state_pkg;

    typedef enum logic [3:0] {
        ST_IDLE,
        ST_ACTIVATE,
        ST_REG0_CFG,
        ST_REG1_CFG,
        ST_WAIT,
        ST_ROW_TRAIN,
        ST_ROW_DATA,
        ST_EOF,
        ST_FIND_READOUT,
        ST_READOUT_SYNC_BETWEEN_SENSORS,
        ST_INTERFACE
    } naneye_ctl_state_t;

endpackage

`endif // _NANEYE_CTL_STATE_PKG_SV_
