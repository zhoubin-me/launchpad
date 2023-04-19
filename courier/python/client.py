# Copyright 2020 DeepMind Technologies Limited. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Python client bindings for Courier RPCs.

Example usage:
server = courier.Server('my_server')
server.Bind('my_function', lambda a, b: a + b)
server.Start()

client = courier.Client('my_server')
result = client.my_function(4, 7)  # 11, evaluated on the server.
"""

from concurrent import futures
import datetime
from typing import List, Optional, Union
import zoneinfo

from courier.python import py_client
# Numpy import needed for proper operation of ../serialization/py_serialize.cc
import numpy  


from pybind11_abseil.status import StatusNotOk as StatusThrown  # pytype: disable=import-error
from pybind11_abseil.status import StatusNotOk  # pytype: disable=import-error


def translate_status(s):
  """Translate Pybind11 status to Exception."""
  exc = StatusNotOk(s.message())
  exc.code = s.code()
  return exc




def exception_handler(func):

  def inner_function(*args, **kwargs):
    try:
      return func(*args, **kwargs)
    except StatusThrown as e:
      raise translate_status(e.status) from e

  return inner_function


def _calculate_deadline(
    timeout: Optional[datetime.timedelta], propagate_deadline: bool
) -> datetime.datetime:
  """Calculate the out-bound deadline from timeout and existing deadline.

  Args:
    timeout: Timeout to apply to all calls. If set to None or a zero-length
      timedelta then no timeout is applied.
    propagate_deadline: Unsupported feature.

  Returns:
    Returns the sooner of (now + timeout) and the existing deadline.
  """
  deadline = datetime.datetime.max.replace(tzinfo=zoneinfo.ZoneInfo('UTC'))
  if timeout:
    deadline_timeout = (
        datetime.datetime.now(tz=zoneinfo.ZoneInfo('UTC')) + timeout
    )
    deadline = min(deadline, deadline_timeout)
  return deadline


class _AsyncClient:
  """Asynchronous client."""

  def __init__(
      self,
      client: 'Client',
      wait_for_ready: bool,
      call_timeout: Optional[datetime.timedelta],
      compress: bool,
      chunk_tensors: bool,
      propagate_deadline: bool = False,
  ):
    self._client = client
    self._wait_for_ready = wait_for_ready
    self._call_timeout = call_timeout
    self._compress = compress
    self._chunk_tensors = chunk_tensors
    self._propagate_deadline = propagate_deadline

  def _build_handler(self, method: str):
    """Build a future handler for a given method."""
    def call(*args, **kwargs):  
      f = futures.Future()

      def set_exception(s):
        try:
          f.set_exception(translate_status(s))
        except futures.InvalidStateError:  # pytype: disable=module-attr
          # Call could have been already canceled by the user.
          pass

      def set_result(r):
        try:
          f.set_result(r)
        except futures.InvalidStateError:
          # Call could have been already canceled by the user.
          pass

      deadline = _calculate_deadline(
          self._call_timeout, self._propagate_deadline
      )

      canceller = self._client.AsyncPyCall(
          method,
          list(args),
          kwargs,
          set_result,
          set_exception,
          self._wait_for_ready,
          deadline,
          self._compress,
          self._chunk_tensors,
      )

      def done_callback(f):
        if f.cancelled():
          canceller.Cancel()

      f.add_done_callback(done_callback)
      return f

    return call

  def __getattr__(self, method):
    """Gets a callable function for the method that returns a future.

    Args:
      method: Name of the method.

    Returns:
      Callable function for the method that returns a future.
    """
    return self._build_handler(method)

  def __call__(self, *args, **kwargs):
    return self._build_handler('__call__')(*args, **kwargs)


class Client:
  """Client class for using Courier RPCs.

  This provides a convenience wrapper around the CLIF bindings which allows
  calling server methods as if they were class methods.
  """

  def __init__(
      self,
      server_address: str,
      compress: bool = False,
      call_timeout: Optional[Union[int, float, datetime.timedelta]] = None,
      wait_for_ready: bool = True,
      chunk_tensors: bool = False,
      *,
      load_balancing_policy: Optional[str] = None,
      propagate_deadline: bool = True,
  ):
    """Initiates a new client that will connect to a server.

    Args:
      server_address: Address of the server. If the string does not start with
        "/" or "localhost" then it will be interpreted as a custom BNS
        registered server_name (constructor passed to Server).
      compress: Whether to use compression.
      call_timeout: Sets a timeout to apply to all calls. If None or 0 then
        no timeout is applied.
      wait_for_ready: Sets `wait_for_ready` on the gRPC::ClientContext. This
        specifies whether to wait for a server to come online.
      chunk_tensors: Unsupported feature.
      load_balancing_policy: gRPC load balancing policy. Use 'round_robin' to
        spread the load across all backends. More details at:
        https://github.com/grpc/grpc/blob/master/doc/load-balancing.md
      propagate_deadline: Unsupported feature.
    """
    self._init_args = (server_address, compress, call_timeout, wait_for_ready)
    self._address = str(server_address)
    self._compress = compress
    self._client = py_client.PyClient(self._address, load_balancing_policy)
    if call_timeout:
      if isinstance(call_timeout, datetime.timedelta):
        self._call_timeout = call_timeout
      else:
        self._call_timeout = datetime.timedelta(seconds=call_timeout)
    else:
      self._call_timeout = None
    self._wait_for_ready = wait_for_ready
    self._chunk_tensors = chunk_tensors
    self._async_client = _AsyncClient(self._client, self._wait_for_ready,
                                      self._call_timeout, self._compress,
                                      self._chunk_tensors, propagate_deadline)
    self._propagate_deadline = propagate_deadline

  def __del__(self):
    self._client.Shutdown()

  def __reduce__(self):
    return self.__class__, self._init_args

  @property
  def address(self) -> str:
    return self._address

  @property
  def futures(self) -> _AsyncClient:
    """Gets an asynchronous client on which a method call returns a future."""
    return self._async_client

  def _build_handler(self, method: str):
    """Build a callable handler for a given method.

    Args:
      method: Name of the method to build.

    Returns:
      Handler for the method.
    """
    @exception_handler
    def func(*args, **kwargs):
      deadline = _calculate_deadline(
          self._call_timeout, self._propagate_deadline
      )

      return self._client.PyCall(
          method,
          list(args),
          kwargs,
          self._wait_for_ready,
          deadline,
          self._compress,
          self._chunk_tensors,
      )

    return func

  def __getattr__(self, method: str):
    """Gets a callable function for the method and sets it as an attribute.

    Args:
      method: Name of the method.

    Returns:
      Callable function for the method.
    """

    func = self._build_handler(method)
    setattr(self, method, func)
    return func

  @exception_handler
  def __call__(self, *args, **kwargs):
    return self._build_handler('__call__')(*args, **kwargs)


@exception_handler
def list_methods(client: Client) -> List[str]:
  """Lists the methods which are available on the server.

  Args:
    client: A client instance.

  Returns:
    List of method names.
  """
  return client._client.ListMethods()  
