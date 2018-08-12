#
# Copyright (C) Stanislaw Adaszewski, 2018
#

cimport numpy as np
from numpy import finfo
from libc.string cimport memset
import random
from ibverbs cimport *

class IBNodeType(object):
    UNKNOWN = IBV_NODE_UNKNOWN
    CA = IBV_NODE_CA
    SWITCH = IBV_NODE_SWITCH
    ROUTER = IBV_NODE_ROUTER
    RNIC = IBV_NODE_RNIC

    EXP_START = IBV_EXP_NODE_TYPE_START
    EXP_MIC = IBV_EXP_NODE_MIC

class IBTransportType(object):
    UNKNOWN = IBV_TRANSPORT_UNKNOWN
    IB = IBV_TRANSPORT_IB,
    IWARP = IBV_TRANSPORT_IWARP,

    EXP_START = IBV_EXP_TRANSPORT_TYPE_START,
    EXP_SCIF = IBV_EXP_TRANSPORT_SCIF

class IBAccessFlags(object):
    LOCAL_WRITE = IBV_ACCESS_LOCAL_WRITE
    REMOTE_WRITE = IBV_ACCESS_REMOTE_WRITE
    REMOTE_READ = IBV_ACCESS_REMOTE_READ
    REMOTE_ATOMIC = IBV_ACCESS_REMOTE_ATOMIC
    MW_BIND = IBV_ACCESS_MW_BIND
    ZERO_BASED = IBV_ACCESS_ZERO_BASED
    ON_DEMAND = IBV_ACCESS_ON_DEMAND

cdef class IBDeviceList(object):
    cdef ibv_device **dev_list
    cdef size_t cnt

    def __init__(self):
        self.dev_list = NULL
        self.cnt = 0
        self.open()

    def open(self):
        dev_list = self.dev_list = ibv_get_device_list(NULL)
        if dev_list == NULL:
            raise RuntimeError('ibv_get_device_list() failed')
        i = 0
        while dev_list[i] != NULL:
            i += 1
        self.cnt = i

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()

    def __del__(self):
        self.close()

    def close(self):
        print('Destroying dev list ...')
        if self.dev_list != NULL:
            ibv_free_device_list(self.dev_list)
            self.dev_list = NULL

    def __getitem__(self, key):
        if not isinstance(key, int) or key < 0 or key >= self.cnt:
            raise IndexError()
        return IBDevice(self, key)

    def __len__(self):
        return self.cnt

cdef class IBDevice(object):
    cdef ibv_device *dev

    def __init__(self, IBDeviceList dev_list, idx):
        self.dev = dev_list.dev_list[idx]

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        pass # self.close()

    def open(self):
        return IBContext(self)

    # def close(self):
        # print('Destroying dev ...')

    @property
    def node_type(self):
        return <int> self.dev.node_type

    @property
    def transport_type(self):
        return <int> self.dev.transport_type

    @property
    def name(self):
        return <bytes> self.dev.name

    @property
    def dev_name(self):
        return <bytes> self.dev.dev_name

    @property
    def dev_path(self):
        return <bytes> self.dev.dev_path

    @property
    def ibdev_path(self):
        return <bytes> self.dev.ibdev_path

cdef class IBContext(object):
    cdef ibv_context *ctx
    cdef ibv_device *dev

    def __init__(self, IBDevice dev):
        self.dev = dev.dev
        self.ctx = NULL
        self.open()

    def open(self):
        ctx = self.ctx = ibv_open_device(self.dev)
        if ctx == NULL:
            raise RuntimeError('ibv_open_device() failed')

    def __enter__(self):
        return self

    def __exit__(self, exc_typ, exc_val, tb):
        self.close()

    def __del__(self):
        self.close()

    def close(self):
        if self.ctx == NULL:
            return
        print('Destroying ctx ...')
        if ibv_close_device(self.ctx) != 0:
            raise RuntimeError('ibv_close_device() failed')
        self.ctx = NULL

    def protection_domain(self):
        return IBProtectionDomain(self)

    def completion_channel(self):
        return IBCompletionChannel(self)

    def completion_queue(self, IBCompletionChannel comp_chan=None, nentries=1):
        return IBCompletionQueue(self, comp_chan, nentries)

cdef class IBProtectionDomain(object):
    cdef ibv_context *ctx
    cdef ibv_pd *pd

    def __init__(self, IBContext ctx):
        self.ctx = ctx.ctx
        self.pd = NULL
        self.open()

    def open(self):
        pd = self.pd = ibv_alloc_pd(self.ctx)
        if pd == NULL:
            raise RuntimeError('ibv_alloc_pd() failed')

    def __enter__(self):
        return self

    def __exit__(self, exc_typ, exc_val, tb):
        self.close()

    def __del__(self):
        self.close()

    def close(self):
        if self.pd == NULL:
            return
        print('Destroying pd ...')
        if ibv_dealloc_pd(self.pd) != 0:
            raise RuntimeError('ibv_dealloc_pd() failed')
        self.pd = NULL

    def memory_region_from_array(self, np.ndarray ary, access):
        return IBMemoryRegion.from_array(self.pd, ary, access)

    def queue_pair(self, rcq, scq):
        return IBQueuePair(self, rcq, scq)

cdef class IBMemoryRegion(object):
    cdef ibv_pd *pd
    cdef void *buf
    cdef size_t sz
    cdef int access
    cdef ibv_mr *mr

    @staticmethod
    cdef from_array(ibv_pd *pd, np.ndarray ary, int access):
        res = IBMemoryRegion()
        res.pd = pd
        res.buf = ary.data
        elem_sz = finfo(ary.dtype).bits // 8
        print('elem_sz:', elem_sz)
        res.sz = ary.size * elem_sz
        res.access = access
        res.open()
        return res

    def __init__(self):
        self.pd = NULL
        self.buf = NULL
        self.sz = 0
        self.access = 0
        self.mr = NULL

    def open(self):
        buf = self.buf
        sz = self.sz
        access = self.access
        print('Registering buf: 0x%08X, sz: %d with acc: %d' % \
            (<uintptr_t> buf, sz, access))
        mr = self.mr = ibv_reg_mr(self.pd, buf, sz, access)
        if mr == NULL:
            raise RuntimeError('ibv_reg_mr() failed')

    def __enter__(self):
        return self

    def __exit__(self, exc_typ, exc_val, tb):
        self.close()

    def __del__(self):
        self.close()

    def close(self):
        if self.mr == NULL:
            return
        print('Destroying mr ...')
        if ibv_dereg_mr(self.mr) != 0:
            raise RuntimeError('ibv_dereg_mr() failed')
        self.mr = NULL

    @property
    def size(self):
        return self.sz

cdef class IBCompletionChannel(object):
    cdef ibv_context *ctx
    cdef ibv_comp_channel *chan

    def __init__(self, IBContext ctx):
        self.ctx = ctx.ctx
        self.chan = NULL
        self.open()

    def open(self):
        chan = self.chan = ibv_create_comp_channel(self.ctx)
        if chan == NULL:
            raise RuntimeError('ibv_create_comp_channel() failed')

    def __enter__(self):
        return self

    def __exit__(self, exc_typ, exc_val, tb):
        self.close()

    def __del__(self):
        self.close()

    def close(self):
        if self.chan == NULL:
            return
        print('Destroying comp chan ...')
        if ibv_destroy_comp_channel(self.chan) != 0:
            raise RuntimeError('ibv_destroy_comp_channel() failed')
        self.chan = NULL

cdef class IBCompletionQueue(object):
    cdef ibv_context *ctx
    cdef ibv_comp_channel *chan
    cdef size_t nentries
    cdef ibv_cq *cq

    def __init__(self, IBContext ctx, IBCompletionChannel chan, size_t nentries):
        self.ctx = ctx.ctx
        self.chan = chan.chan if chan is not None else NULL
        self.nentries = nentries
        self.cq = NULL
        self.open()

    def open(self):
        cq = self.cq = ibv_create_cq(self.ctx, self.nentries, NULL, self.chan, 0)
        if cq == NULL:
            raise RuntimeError('ibv_create_cq() failed')

    def __enter__(self):
        return self

    def __exit__(self, exc_typ, exc_val, tb):
        self.close()

    def __del__(self):
        self.close()

    def close(self):
        if self.cq == NULL:
            return
        print('Destroying cq ...')
        if ibv_destroy_cq(self.cq) != 0:
            raise RuntimeError('ibv_destroy_cq() failed')
        self.cq = NULL

    def wait_complete(self):
        cdef int ne = 0
        cdef ibv_wc wc
        memset(&wc, 0, sizeof(ibv_wc))

        while ne == 0:
            ne = ibv_poll_cq(self.cq, 1, &wc);

        if ne < 0:
            raise RuntimeError('ibv_poll_cq() failed')

        if wc.status != IBV_WC_SUCCESS:
            raise RuntimeError('Work request completion failed, wr_id: %d, status: %d' % (wc.wr_id, wc.status))

cdef int ibv_post_send(ibv_qp *qp, ibv_send_wr *wr, ibv_send_wr **bad_wr):
    return qp.context.ops.post_send(qp, wr, bad_wr)

cdef int ibv_poll_cq(ibv_cq *cq, int num_entries, ibv_wc *wc):
    return cq.context.ops.poll_cq(cq, num_entries, wc)

cdef class IBQueuePair(object):
    cdef ibv_pd *pd
    cdef ibv_cq *rcq
    cdef ibv_cq *scq
    cdef ibv_qp *qp

    def __init__(self, IBProtectionDomain pd,
        IBCompletionQueue rcq, IBCompletionQueue scq):

        self.pd = pd.pd
        self.rcq = rcq.cq
        self.scq = scq.cq
        self.qp = NULL
        self.open()

    def open(self):
        cdef ibv_qp_init_attr attr
        memset(&attr, 0, sizeof(ibv_qp_init_attr))

        attr.recv_cq = self.rcq
        attr.send_cq = self.scq
        attr.qp_type = IBV_QPT_RC

        attr.cap.max_send_wr = 100
        attr.cap.max_recv_wr = 1
        attr.cap.max_send_sge = 1
        attr.cap.max_recv_sge = 1
        attr.cap.max_inline_data = 0

        qp = self.qp = ibv_create_qp(self.pd, &attr)
        if qp == NULL:
            raise RuntimeError('ibv_create_qp() failed')

    def __enter__(self):
        return self

    def __exit__(self, exc_typ, exc_val, tb):
        self.close()

    def __del__(self):
        self.close()

    def close(self):
        if self.qp == NULL:
            return
        print('Destroying qp ...')
        if ibv_destroy_qp(self.qp) != 0:
            raise RuntimeError('ibv_destroy_qp() failed')
        self.qp = NULL

    def change_state_init(self, ibport):
        cdef ibv_qp_attr attr
        memset(&attr, 0, sizeof(ibv_qp_attr))
        attr.qp_state = IBV_QPS_INIT
        attr.pkey_index = 0
        attr.port_num = ibport
        attr.qp_access_flags = IBV_ACCESS_REMOTE_WRITE

        if ibv_modify_qp(self.qp, &attr, IBV_QP_STATE | IBV_QP_PKEY_INDEX |
            IBV_QP_PORT | IBV_QP_ACCESS_FLAGS) != 0:
            raise RuntimeError("ibv_modify_qp() failed")

    def change_state_ready_to_receive(self, dest_qp, rq_psn, rc_lid, ibport):
        cdef ibv_qp_attr attr
        memset(&attr, 0, sizeof(ibv_qp_attr))

        attr.qp_state              = IBV_QPS_RTR
        attr.path_mtu              = IBV_MTU_2048
        attr.dest_qp_num           = dest_qp
        attr.rq_psn                = rq_psn
        attr.max_dest_rd_atomic    = 1
        attr.min_rnr_timer         = 12
        attr.ah_attr.is_global     = 0
        attr.ah_attr.dlid          = rc_lid
        attr.ah_attr.sl            = 1
        attr.ah_attr.src_path_bits = 0
        attr.ah_attr.port_num      = ibport

        if ibv_modify_qp(self.qp, &attr, IBV_QP_STATE | IBV_QP_AV |
            IBV_QP_PATH_MTU | IBV_QP_DEST_QPN | IBV_QP_RQ_PSN |
            IBV_QP_MAX_DEST_RD_ATOMIC | IBV_QP_MIN_RNR_TIMER) != 0:
            raise RuntimeError('ibv_modify_qp() failed')

    def change_state_ready_to_send(self, sq_psn):
        cdef ibv_qp_attr attr
        memset(&attr, 0, sizeof(ibv_qp_attr))

        attr.qp_state              = IBV_QPS_RTS
        attr.timeout               = 14
        attr.retry_cnt             = 7
        attr.rnr_retry             = 7
        attr.sq_psn                = sq_psn
        attr.max_rd_atomic         = 1

        if ibv_modify_qp(self.qp, &attr, IBV_QP_STATE | IBV_QP_TIMEOUT |
            IBV_QP_RETRY_CNT | IBV_QP_RNR_RETRY | IBV_QP_SQ_PSN |
            IBV_QP_MAX_QP_RD_ATOMIC) != 0:
            raise RuntimeError('ibv_modify_qp() failed')

    def post_send(self, IBMemoryRegion mr, uint64_t wr_id, uint64_t vaddr, uint32_t rkey,
        ofs=0, sz=None):
        print('post_send(), local_vaddr: 0x%08X, remote_vaddr: 0x%08X, ' \
            'lkey: 0x%08X, rkey: 0x%08X, ofs: %d, sz: %d' % \
            (<uint64_t> mr.buf, vaddr, mr.mr.lkey, rkey, ofs, sz))

        cdef ibv_sge sge
        memset(&sge, 0, sizeof(ibv_sge))
        sge.addr = (<uint64_t> mr.buf) + ofs
        sge.length = sz if sz is not None else mr.sz
        sge.lkey = mr.mr.lkey

        cdef ibv_send_wr wr
        memset(&wr, 0, sizeof(ibv_send_wr))
        wr.wr.rdma.remote_addr = vaddr + ofs
        wr.wr.rdma.rkey = rkey
        wr.wr_id = wr_id
        wr.sg_list = &sge
        wr.num_sge = 1
        wr.opcode = IBV_WR_RDMA_WRITE
        wr.send_flags = IBV_SEND_SIGNALED
        wr.next = NULL

        if ibv_post_send(self.qp, &wr, NULL) != 0:
            raise RuntimeError('ibv_post_send() failed')

class IBConnSpec(object):
    def __init__(self):
        self.lid = None
        self.qpn = None
        self.psn = None
        self.rkey = None
        self.vaddr = None
        self.ibport = None
        self.max_msg_sz = None

    @staticmethod
    def from_local(IBContext ctx,
        uint8_t ibport, IBQueuePair qp,
        IBMemoryRegion mr):

        res = IBConnSpec()
        cdef ibv_port_attr attr;
        if ibv_query_port(ctx.ctx, ibport, &attr) != 0:
            raise RuntimeError('ibv_query_port() failed')
        res.lid = attr.lid
        res.qpn = qp.qp.qp_num
        res.psn = random.randint(0, 2**32)
        res.rkey = mr.mr.rkey
        res.vaddr = <uintptr_t> mr.buf
        res.ibport = ibport
        res.max_msg_sz = attr.max_msg_sz

        return res

    @staticmethod
    def from_string(s):
        (lid, qpn, psn, rkey, vaddr, ibport) = \
            map(lambda x: int(x, 16), s.split(':'))

        res = IBConnSpec()
        res.lid = lid
        res.qpn = qpn
        res.psn = psn
        res.rkey = rkey
        res.vaddr = vaddr
        res.ibport = ibport

        return res

    @staticmethod
    def from_dict(d):
        res = IBConnSpec()
        res.lid = int(d['lid'][2:], 16)
        res.qpn = int(d['qpn'][2:], 16)
        res.psn = int(d['psn'][2:], 16)
        res.rkey = int(d['rkey'][2:], 16)
        res.vaddr = int(d['vaddr'][2:], 16)
        res.ibport = d['ibport']
        res.max_msg_sz = d['max_msg_sz']
        return res

    def to_string(self):
        return ('%04x:%06x:%06x:%08x:%016Lx:%02x' % (self.lid, self.qpn,
            self.psn, self.rkey, self.vaddr, self.ibport))

    def to_dict(self):
        return {
            'lid': '0x%X' % self.lid,
            'qpn': '0x%X' % self.qpn,
            'psn': '0x%X' % self.psn,
            'rkey': '0x%X' % self.rkey,
            'vaddr': '0x%X' % self.vaddr,
            'ibport': self.ibport,
            'max_msg_sz': self.max_msg_sz
        }
