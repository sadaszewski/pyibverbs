#!/usr/bin/env python
from ibverbs import IBDeviceList, \
    IBAccessFlags as acc, \
    IBConnSpec
import numpy as np
from argparse import ArgumentParser
import zmq


def create_parser():
    parser = ArgumentParser()
    parser.add_argument('--host', type=str, default='rkalbhpc002:8788')
    parser.add_argument('--ibport', type=int, default=1)
    return parser


def main():
    parser = create_parser()
    args = parser.parse_args()

    ctx = zmq.Context()
    sock = ctx.socket(zmq.REQ)

    A = np.random.randint(0, 10, (50000, 2048)).astype(np.float64)
    print('A:', A)

    dlst = IBDeviceList()
    ctx = dlst[0].open()
    pd = ctx.protection_domain()
    mr = pd.memory_region_from_array(A, acc.LOCAL_WRITE | acc.REMOTE_WRITE)
    chan = ctx.completion_channel()
    rcq = ctx.completion_queue()
    scq = ctx.completion_queue(chan)
    qp = pd.queue_pair(rcq, scq)

    sock.connect('tcp://%s' % args.host)
    print('Connected to %s ...' % args.host)

    local_spec = IBConnSpec.from_local(ctx, args.ibport, qp, mr)
    print ('local conn spec:', local_spec.to_dict())

    sock.send_json({
        'msg': 'init_array_write',
        'shape': A.shape,
        'dtype': str(A.dtype),
        'conn_spec': local_spec.to_dict()
    })

    msg = sock.recv_json()
    assert msg['msg'] == 'confirm_array_write'
    remote_spec = IBConnSpec.from_dict(msg['conn_spec'])
    print('remote_spec:', msg['conn_spec'])

    qp.change_state_init(args.ibport)
    print('change_state_init() OK')
    qp.change_state_ready_to_receive(remote_spec.qpn,
        remote_spec.psn, remote_spec.lid, args.ibport)
    print('change_state_ready_to_receive() OK')
    qp.change_state_ready_to_send(local_spec.psn)
    print('change_state_ready_to_send() OK')

    qp.post_send(mr, 3, remote_spec.vaddr, remote_spec.rkey)
    print('post_send() OK, waiting for completion ...')

    scq.wait_complete()
    print('wait_complete() OK, sending kick ...')

    sock.send_json({
        'msg': 'finish_array_write'
    })
    msg = sock.recv_json()
    assert msg['msg'] == 'array_write_finished'

    print('Transfer successful')

if __name__ == '__main__':
    main()
