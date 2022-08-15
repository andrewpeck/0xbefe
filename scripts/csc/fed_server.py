# install spyne like this:
#   sudo easy_install-3.6 spyne
#   sudo easy_install-3.6 lxml

from spyne import Application, rpc, ServiceBase, Iterable, Integer, Unicode
from spyne.model import ComplexModel

from spyne.protocol.soap import Soap11
from spyne.server.wsgi import WsgiApplication

import logging
import sys
import common.utils as utils

# remote
if len(sys.argv) > 1 and "rpyc_classic.py" not in sys.argv[0]:
    hostname = sys.argv[1]
    utils.heading("Connecting to %s" % hostname)
    import rpyc
    conn = rpyc.classic.connect(hostname)
    conn._config["sync_request_timeout"] = 240
    rw = conn.modules["common.rw_reg"]
    daq_ctrl = conn.modules["common.daq_ctrl"]

# local
else:
    utils.heading("Running locally")
    import common.rw_reg as rw
    import common.daq_ctrl as daq_ctrl

daq = None

class MyUnicode(Unicode):
    __namespace__ = "http://www.w3.org/2001/XMLSchema"
    __type_name__ = "string"

class MyProps(ComplexModel):
    __namespace__ = "urn:xdaq-application:emu::fed::Communicator::Application"
    __type_name__ = "properties"
    fedState = Unicode(type_name="my_string")

class MyResponse(ComplexModel):
    __namespace__ = "urn:xdaq-application:emu::fed::Communicator::Application"
    properties = MyProps

class FedService(ServiceBase):

    @rpc(_returns=Iterable(Unicode))
    def Halt(ctx):
        yield 'success'

    @rpc(_returns=Iterable(Unicode))
    def Configure(ctx):
        daq.configure()
        print("FED Server: received 'Configure' command")
        yield 'success'

    @rpc(_returns=Iterable(Unicode))
    def Enable(ctx):
        daq.enable()
        print("FED Server: received 'Enable' command")
        yield 'success'

    @rpc(_returns=Iterable(Unicode))
    def Halt(ctx):
        daq.halt()
        print("FED Server: received 'Halt' command")
        yield 'success'

    @rpc(MyProps, _returns=MyResponse, _body_style='bare')
    def ParameterGet(ctx, properties):
        print("JOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO")
        if properties is None:
            print("prop is None, man...")
        else:
            print("prop fed state = %s" % properties.fedState)

        attrs = dir(properties)
        for a in attrs:
            print(a)
        # print("-------------")
        # print(prop.as_dict())
        ret_props = MyProps()
        ret_props.fedState = "Configured"
        # ret_props.fedState.Value = "Configured"
        # ret_props.fedState.__namespace__ = "http://www.w3.org/2001/XMLSchema"
        resp = MyResponse()
        resp.properties = ret_props
        return resp
        # yield ret

class MySoap11(Soap11):
    def __init__(self, *args, **kwargs):
        super(MySoap11, self).__init__(*args, **kwargs)
        self.parse_xsi_type = False

application = Application([FedService],
    tns='urn:xdaq-soap:3.0',
    in_protocol=MySoap11(validator='soft'),
    # in_protocol=Soap11(validator='lxml'),
    out_protocol=MySoap11()
)

# app_with_log = LoggingMiddleware(application)

if __name__ == '__main__':

    rw.parse_xml()
    daq = daq_ctrl.DaqCtrl(verbose=True)

    # You can use any Wsgi server. Here, we chose
    # Python's built-in wsgi server but you're not
    # supposed to use it in production.
    from wsgiref.simple_server import make_server

    # logger = logging.getLogger("spyne.util")

    logging.basicConfig(level=logging.DEBUG)
    logging.getLogger('').setLevel(logging.DEBUG)
    logging.getLogger("spyne.util").setLevel(logging.DEBUG)
    logging.getLogger('spyne.protocol').setLevel(logging.DEBUG)
    logging.getLogger('spyne.protocol.xml').setLevel(logging.DEBUG)
    logging.getLogger('spyne.protocol.soap11').setLevel(logging.DEBUG)

    wsgi_app = WsgiApplication(application)
    server = make_server('0.0.0.0', 8000, wsgi_app)
    server.serve_forever()
