#!/usr/bin/env python
from ibverbs import IBDeviceList, \
    IBAccessFlags as acc, \
    IBConnSpec
import numpy as np
from argparse import ArgumentParser
import zmq
from time import time, sleep


def create_parser():
    parser = ArgumentParser()
    parser.add_argument('--port', type=int, default=8788)
    parser.add_argument('--ibport', type=int, default=1)
    return parser


def main():
    parser = create_parser()
    args = parser.parse_args()

    ctx = zmq.Context()
    sock = ctx.socket(zmq.REP)
    sock.bind('tcp://*:%d' % args.port)
    print('Listening on port %d ...' % args.port)

    dlst = IBDeviceList()
    print('Device name:', dlst[0].name)
    ctx = dlst[0].open()
    pd = ctx.protection_domain()
    chan = ctx.completion_channel()
    rcq = ctx.completion_queue()
    scq = ctx.completion_queue(chan)

    while True:
        msg = sock.recv_json()
        assert msg['msg'] == 'init_array_write'
        shape = msg['shape']
        dtype = msg['dtype']
        remote_spec = IBConnSpec.from_dict(msg['conn_spec'])
        print('Received init_array_write request with shape:', shape, 'dtype:', dtype)
        print('Remote conn spec:', msg['conn_spec'])

        A = np.zeros(shape, dtype=dtype)
        qp = pd.queue_pair(rcq, scq)
        mr = pd.memory_region_from_array(A, acc.LOCAL_WRITE | acc.REMOTE_WRITE)
        local_spec = IBConnSpec.from_local(ctx, args.ibport, qp, mr)
        print ('local spec:', local_spec.to_dict())

        qp.change_state_init(args.ibport)
        qp.change_state_ready_to_receive(remote_spec.qpn,
            remote_spec.psn, remote_spec.lid, args.ibport)
        # qp.change_state_ready_to_send(local_spec.psn)
        sock.send_json({
            'msg': 'confirm_array_write',
            'conn_spec': local_spec.to_dict()
        })
        print('Infiniband ready to receive, waiting for TCP kick when transfer finished ...')
        t = time()
        # sleep(5)

        msg = sock.recv_json()
        assert msg['msg'] == 'finish_array_write'
        print('Write completed successfully')

        print('Elapsed time: %.2f s' % (time() - t))

        print('A:', A)

        sock.send_json({
            'msg': 'array_write_finished'
        })



if __name__ == '__main__':
    main()
