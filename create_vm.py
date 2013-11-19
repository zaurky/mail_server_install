#!/usr/bin/python
# -*- coding: utf-8 -*-

import time
from xmlrpclib import ServerProxy
from optparse import OptionParser


class VMCreate:
    _url = 'https://rpc.gandi.net/xmlrpc/'

    def __init__(self, config):
        self.api = ServerProxy(self._url)
        if not (config.apikey and config.domain):
            raise

        self.apikey = config.apikey
        self.domain = config.domain
        self.hostname = config.hostname
        self.password = config.password
        self.ssh_key = config.ssh_key
        self.datacenter = config.datacenter
        self.memory = config.memory
        self.data_size = config.data_size

    def get_source_disk(self):
        return self.api.hosting.image.list(self.apikey, {'label': 'Debian 7',
                                                         'os_arch': 'x86-32'})

    def create_disk(self, size):
        return self.api.hosting.disk.create(self.apikey, {
                                              'datacenter_id': self.datacenter,
                                              'name': 'data%s' % self.hostname,
                                              'size': size})

    def attach_disk(self, vm_id, disk_id):
        return self.api.hosting.vm.disk_attach(self.apikey, vm_id, disk_id)

    def create_vm(self, source_id):
        vm_params = {'hostname': self.hostname,
                     'datacenter_id': self.datacenter,
                     'bandwidth': 102400,
                     'ai_active': 0,
                     'memory': self.memory,
                     'ip_version': 4,
                     'cores': 1,
                     'login': 'admin'}

        if self.password:
            vm_params['password'] = self.password

        if self.ssh_key:
            vm_params['ssh_key'] = self.ssh_key

        disk_params = {'datacenter_id': self.datacenter,
                       'name': 'sysdisk%s' % self.hostname}

        return self.api.hosting.vm.create_from(self.apikey,
                                               vm_params,
                                               disk_params,
                                               source_id)

    def info_op(self, op_id):
        return self.api.operation.info(self.apikey, op_id)

    def info_iface(self, vm_id):
        return self.api.hosting.vm.info(self.apikey, vm_id)['ifaces'][0]

    def update_ip(self, ip_id, reverse):
        self.api.hosting.ip.update(self.apikey, ip_id, {'reverse': reverse})

    def process(self):
        source_disk = self.get_source_disk()
        ops = self.create_vm(source_disk['disk_id'])
        vm_id = ops[2]['vm_id']

        disk_id = self.create_disk(self.data_size)['disk_id']

        attach = self.attach_disk(vm_id, disk_id)
        while self.info_op(attach['id'])['step'] in ('BILL', 'WAIT', 'RUN'):
            time.sleep(60)

        step = self.info_op(attach['id'])
        if step != 'DONE':
            raise

        iface = self.info_iface(vm_id)
        ip_versions = dict([(ip['version'], ip['ip']) for ip in iface['ips']])
        reverse = 'mail.%s' % self.hostname
        [self.update_ip(ip['id'], reverse) for ip in iface['ips']]

        print "DOMAIN %s" % self.domain
        print "IPV4 %s" % ip_versions[4]
        print "IPV6 %s" % ip_versions[6]


class Config(OptionParser):

    _ssh_key = None
    def __init__(self, usage=None, description=None):
        OptionParser.__init__(self, usage=usage, description=description)
        self.add_option("-p", "--password",
            dest="password",
            help="the vm password",
            default=None,
        )

        self.add_option("-s", "--ssh_key",
            dest="ssh_key",
            help="a public ssh key to acess the vm",
            default=None,
        )

        self.add_option("-d", "--domain",
            dest="domain",
            help="the domain for the email",
            default=None,
        )

        self.add_option("-a", "--apikey",
            dest="apikey",
            help="the gandi api apikey",
            default=None,
        )

        self.add_option("--datacenter",
            dest="datacenter",
            help="the datacenter we should put the vm in",
            default=1,
        )

        self.add_option("--memory",
            dest="memory",
            help="the vm memory",
            default=256,
        )

        self.add_option("--hostname",
            dest="hostname",
            help="the vm hostname",
            default=None,
        )

        self.add_option("--size",
            dest="size",
            help="the data disk size",
            default=10240,
        )

        (self.options, _args) = self.parse_args()
        if not (self.options.password or self.options.ssh_key):
            raise

    @property
    def apikey(self):
        return self.options.apikey

    @property
    def domain(self):
        return self.options.domain

    @property
    def hostname(self):
        return (self.options.hostname if self.options.hostname
                else self.domain.replace('.', ''))

    @property
    def password(self):
        return self.options.password

    @property
    def ssh_key(self):
        if not self._ssh_key:
            if os.path.exists(self.options.ssh_key):
                with open(self.options.ssh_key) as filehandle:
                    self._ssh_key = filehandle.read()
        return self._ssh_key

    @property
    def datacenter(self):
        return self.options.datacenter

    @property
    def memory(self):
        return self.options.memory

    @property
    def data_size(self):
        return self.options.size


def main():
    config = Config(
        usage='%prog [options]',
        description='create a new vm on the Gandi infrastructure',
    )

    create = VMCreate(config)
    create.process()


if __name__ == '__main__':
    main()

