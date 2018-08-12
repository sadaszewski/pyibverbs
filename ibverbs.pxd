#
# Copyright (C) Stanislaw Adaszewski, 2018
#

from libc.stdint cimport uintptr_t, \
    uint64_t, \
    uint32_t, \
    uint16_t, \
    uint8_t

cdef extern from "<infiniband/verbs.h>":

    # NOTE: Enums

    enum:
        IBV_SYSFS_NAME_MAX,
        IBV_SYSFS_PATH_MAX

    enum ibv_node_type:
        IBV_NODE_UNKNOWN,
        IBV_NODE_CA,
        IBV_NODE_SWITCH,
        IBV_NODE_ROUTER,
        IBV_NODE_RNIC,

        IBV_EXP_NODE_TYPE_START,
        IBV_EXP_NODE_MIC

    enum ibv_transport_type:
        IBV_TRANSPORT_UNKNOWN,
        IBV_TRANSPORT_IB,
        IBV_TRANSPORT_IWARP,

        IBV_EXP_TRANSPORT_TYPE_START,
        IBV_EXP_TRANSPORT_SCIF

    enum ibv_access_flags:
        IBV_ACCESS_LOCAL_WRITE,
        IBV_ACCESS_REMOTE_WRITE,
        IBV_ACCESS_REMOTE_READ,
        IBV_ACCESS_REMOTE_ATOMIC,
        IBV_ACCESS_MW_BIND,
        IBV_ACCESS_ZERO_BASED,
        IBV_ACCESS_ON_DEMAND

    enum ibv_qp_type:
        IBV_QPT_RC,
        IBV_QPT_UC,
        IBV_QPT_UD,

        IBV_QPT_XRC,
        IBV_QPT_RAW_PACKET,
        IBV_QPT_RAW_ETH,
        IBV_QPT_XRC_SEND,
        IBV_QPT_XRC_RECV,

        IBV_EXP_QP_TYPE_START,
        IBV_EXP_QPT_DC_INI

    enum ibv_qp_state:
        IBV_QPS_RESET,
        IBV_QPS_INIT,
        IBV_QPS_RTR,
        IBV_QPS_RTS,
        IBV_QPS_SQD,
        IBV_QPS_SQE,
        IBV_QPS_ERR,
        IBV_QPS_UNKNOWN

    enum ibv_qp_attr_mask:
        IBV_QP_STATE,
        IBV_QP_CUR_STATE,
        IBV_QP_EN_SQD_ASYNC_NOTIFY,
        IBV_QP_ACCESS_FLAGS,
        IBV_QP_PKEY_INDEX,
        IBV_QP_PORT,
        IBV_QP_QKEY,
        IBV_QP_AV,
        IBV_QP_PATH_MTU,
        IBV_QP_TIMEOUT,
        IBV_QP_RETRY_CNT,
        IBV_QP_RNR_RETRY,
        IBV_QP_RQ_PSN,
        IBV_QP_MAX_QP_RD_ATOMIC,
        IBV_QP_ALT_PATH,
        IBV_QP_MIN_RNR_TIMER,
        IBV_QP_SQ_PSN,
        IBV_QP_MAX_DEST_RD_ATOMIC,
        IBV_QP_PATH_MIG_STATE,
        IBV_QP_CAP,
        IBV_QP_DEST_QPN

    enum ibv_mtu:
        IBV_MTU_256,
        IBV_MTU_512,
        IBV_MTU_1024,
        IBV_MTU_2048,
        IBV_MTU_4096

    enum ibv_wr_opcode:
        IBV_WR_RDMA_WRITE,
        IBV_WR_RDMA_WRITE_WITH_IMM,
        IBV_WR_SEND,
        IBV_WR_SEND_WITH_IMM,
        IBV_WR_RDMA_READ,
        IBV_WR_ATOMIC_CMP_AND_SWP,
        IBV_WR_ATOMIC_FETCH_AND_ADD,
        IBV_WR_LOCAL_INV,
        IBV_WR_BIND_MW,
        IBV_WR_SEND_WITH_INV

    enum ibv_send_flags:
        IBV_SEND_FENCE,
        IBV_SEND_SIGNALED,
        IBV_SEND_SOLICITED,
        IBV_SEND_INLINE

    enum ibv_wc_status:
        IBV_WC_SUCCESS

    # NOTE: Structs

    struct ibv_device:
        int node_type
        int transport_type
        char name[IBV_SYSFS_NAME_MAX]
        char dev_name[IBV_SYSFS_NAME_MAX]
        char dev_path[IBV_SYSFS_NAME_MAX]
        char ibdev_path[IBV_SYSFS_NAME_MAX]

    struct ibv_qp_cap:
        uint32_t max_send_wr
        uint32_t max_recv_wr
        uint32_t max_send_sge
        uint32_t max_recv_sge
        uint32_t max_inline_data

    struct ibv_qp_init_attr:
        ibv_cq *send_cq
        ibv_cq *recv_cq
        ibv_qp_cap cap
        int qp_type

    struct ibv_global_route:
        pass

    struct ibv_ah_attr:
        ibv_global_route grh
        uint16_t dlid
        uint8_t sl
        uint8_t src_path_bits
        uint8_t static_rate
        uint8_t is_global
        uint8_t port_num

    struct ibv_qp_attr:
        ibv_qp_state qp_state
        uint16_t pkey_index
        uint8_t port_num
        int qp_access_flags
        int path_mtu
        uint32_t dest_qp_num
        uint32_t rq_psn
        uint8_t max_dest_rd_atomic
        uint8_t min_rnr_timer
        ibv_ah_attr ah_attr
        uint8_t timeout
        uint8_t retry_cnt
        uint8_t rnr_retry
        uint32_t sq_psn
        uint8_t max_rd_atomic

    struct ibv_pd:
        pass

    struct ibv_context_ops:
        int (*post_send)(ibv_qp *qp, ibv_send_wr *wr,
            ibv_send_wr **bad_wr)
        int (*poll_cq)(ibv_cq *cq, int num_entries,
            ibv_wc *wc)

    struct ibv_context:
        ibv_context_ops ops

    struct ibv_mr:
        uint32_t lkey
        uint32_t rkey

    struct ibv_comp_channel:
        pass

    struct ibv_cq:
        ibv_context *context

    struct ibv_qp:
        uint32_t qp_num
        ibv_context *context

    struct ibv_port_attr:
        uint16_t lid
        uint32_t max_msg_sz

    struct ibv_sge:
        uint64_t addr
        uint32_t length
        uint32_t lkey

    struct ibv_send_wr_rdma:
        uint64_t remote_addr
        uint32_t rkey

    struct ibv_send_wr_atomic:
        uint64_t remote_addr
        uint64_t compare_add
        uint64_t swap
        uint32_t rkey

    struct ibv_ah:
        pass

    struct ibv_send_wr_ud:
        ibv_ah *ah
        uint32_t remote_qpn
        uint32_t remote_qkey

    union ibv_send_wr_wr:
        ibv_send_wr_rdma rdma
        ibv_send_wr_atomic atomic
        ibv_send_wr_ud ud

    struct ibv_send_wr:
        uint64_t wr_id
        ibv_send_wr *next
        ibv_sge *sg_list
        int num_sge;
        ibv_wr_opcode opcode
        int send_flags
        uint32_t imm_data       # in network byte order
        ibv_send_wr_wr wr

    struct ibv_wc:
        uint64_t wr_id
        int status
        int opcode

    # NOTE: Functions

    ibv_device **ibv_get_device_list(int *num_devices)
    void ibv_free_device_list(ibv_device **list)

    ibv_context* ibv_open_device(ibv_device*)
    int ibv_close_device(ibv_context*)

    ibv_pd* ibv_alloc_pd(ibv_context *ctx)
    int ibv_dealloc_pd(ibv_pd*)

    ibv_mr* ibv_reg_mr(ibv_pd *pd, void *addr, size_t length, int access)
    int ibv_dereg_mr(ibv_mr *mr)

    ibv_comp_channel* ibv_create_comp_channel(ibv_context *ctx)
    int ibv_destroy_comp_channel(ibv_comp_channel *chan)

    ibv_cq* ibv_create_cq(ibv_context *ctx, int cqe, void *cq_context,
        ibv_comp_channel *chan, int comp_vector)
    int ibv_destroy_cq(ibv_cq *cq)

    ibv_qp* ibv_create_qp(ibv_pd *pd, ibv_qp_init_attr *qp_init_attr)
    int ibv_destroy_qp(ibv_qp *qp)
    int ibv_modify_qp(ibv_qp *qp, ibv_qp_attr *attr, int attr_mask)

    int ibv_query_port(ibv_context *context, uint8_t port_num,
        ibv_port_attr *port_attr)
