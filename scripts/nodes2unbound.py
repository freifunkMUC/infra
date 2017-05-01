#!/usr/bin/env python

import json

nodes = json.load(file('nodes.json'))

timestamp = filter(lambda c: c.isdigit(), nodes['timestamp'])

hosts = [(i['nodeinfo']['node_id'],
          i['nodeinfo']['hostname'].replace('.', '-').replace(' ', '-'),
          filter(lambda s: not s.startswith('fe80'),
                 i['nodeinfo']['network']['addresses']))
         for i in nodes['nodes']]

print 'server:'
print '  local-zone: "." deny'
print '  local-zone: "1.0.a.0.8.0.6.0.1.0.0.2.ip6.arpa" static'
print '  local-zone: "f.f.f.4.0.c.f.f.f.e.d.f.ip6.arpa" static'
print '  local-zone: "node.ffmuc.net" static'
print '  local-data: "node.ffmuc.net. 600 IN NS ns.node.ffmuc.net."'
print '  local-data: "node.ffmuc.net. 600 IN SOA ns.node.ffmuc.net. admin.ffmuc.net. %s 3600 1200 604800 600"' % (timestamp)
print ''

for (nodeid, host, addrs) in hosts:
    for addr in addrs:
        for h in [ nodeid, host ]:
            try:
                print '  local-data: "%s.node.ffmuc.net. 600 IN AAAA %s"' % (h, addr)
                print '  local-data-ptr: "%s %s.node.ffmuc.net"' % (addr, h)
            except UnicodeEncodeError:
                pass
