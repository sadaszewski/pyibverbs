# pyibverbs
Minimalistic Python version of the Linux VERBS API for Infiniband

Installation:
```
cython ibverbs.pyx
gcc -c ibverbs.c -o ibverbs.o
gcc -shared ibverbs.o -o ibverbs.so -lpython3.6 -libverbs
cp -iv ibverbs.so /usr/lib/python3.6/site-packages/ibverbs.so
```

Usage:
```
from ibverbs import IBDeviceList, \
  IBAccessFlags as acc
import numpy as np

A = np.zeros((100, 100))

#
# ibport, remote_qpn, remote_psn, remote_lid,
# local_psn, remote_vaddr and remote_rkey
# must be established using a side-channel
#
    
with IBDeviceList() as dlst,
  dlst[0].open() as ctx,
  ctx.protection_domain() as pd,
  pd.memory_region_from_array(A, acc.LOCAL_WRITE | acc.REMOTE_WRITE) as mr,
  ctx.completion_channel() as chan,
  ctx.completion_queue() as rcq,
  ctx.completion_queue(chan) as scq,
  pd.queue_pair(rcq, scq) as qp:
  
  qp.change_state_init(ibport)
  qp.change_state_ready_to_receive(remote_qpn,
    remote_psn, remote_lid, ibport)
  qp.change_state_ready_to_send(local_psn)
  qp.post_send(mr, 3, remote_vaddr, remote_rkey)
  scq.wait_complete()
```

Primitives for side channel data encapsulation and exchange are provided in IBConnSpec class. Examples of usage for data send/receive are in test_verbs_cli.py and test_verbs_srv.py.
