## A message event queue implementation
##
##To start listening, init a Subject object to return a pointer to a Subject on the shared heap
##so that all published messages are handled on other threads
##
##Must be compiled with ``--threads:on`` for channels and threads
##
##Example
##========
##
##.. code-block::nim
##  import nimobserver  
##
##  proc onNotify(observer: myObserverClass, message: MyMessageClass) =
##    echo "Notified of message " & $message
##
##  let globalTestSub: SubjectPtr[MessagePtr] = initSubject[MessagePtr]()
##  globalTestSub.add(MyObserverClass)
##  globalTestSub.publish(MyMessageClass)
##

from threadpool import spawn
from os import sleep
from typetraits import name

type
  BaseObserver* = ref object {.inheritable.} ## \
    ##Base Observer Class

  BaseMessage* = ref object {.inheritable.}

  Subject*[T] = object {.inheritable.}
    ##The Subject keeps track of observers and maintains an open channel to handle message type ``T``. \
    ##``T`` must be a pointer in order to be accessible by the shared Subject
    observers: seq[BaseObserver]
    channel: Channel[T]

  SubjectPtr*[T] = ptr Subject[T]

method onNotify*(observer: BaseObserver, message: ptr BaseMessage) {.base gcsafe.} = 
  ## Base method for observers to implement. Observers are notified when a message is received
  echo "Base Notification:: Data value: " 

method notify[T](subject: SubjectPtr[T], notification: ptr BaseMessage) {.base gcsafe.} =
  ## Base notify method. Alerts all observers when a message is processed
  for observer in subject.observers:
    observer.onNotify(notification)

method update[T](subject: SubjectPtr[T]) {.base thread.} =
  ## Blocks until a message is published on the subject's channel, then sends a call to notify observers
  while true:
    let msg = recv(subject.channel)
    subject.notify(cast[ptr BaseMessage](msg))

method publish*[T](subject: SubjectPtr[T], message: T) {.base.} =
  ## Send our message through our channel, which will notify any observers
  subject.channel.send message

method addObserver*[T](subject: SubjectPtr[T], observer: BaseObserver) {.base.} =
  ## Add an Observer to be notified on a message being received
  subject.observers.add(observer)

method removeObserver*[T](subject: SubjectPtr[T], observer: BaseObserver) {.base.} =
  ## Remove an Observer, causing it to no longer be notified when a message is published
  assert subject.observers.contains(observer)
  subject.observers.delete(subject.observers.find(observer))

proc newSubject*[T](): SubjectPtr[T] =
  ## Create a new SubjectPtr on the shared heap
  result = createShared(Subject[T])
  result.observers = @[]
  open(result.channel)

proc initSubject*[T](): SubjectPtr[T] =
  ## Initialise a SubjectPtr and wait for messages on another thread
  result = newSubject[T]()
  spawn result.update()

proc destroySubject*[T](subject: SubjectPtr[T]) =
  ## Deallocate shared memory
  deallocShared(subject)

proc `$`*(x: BaseObserver): string =
  ##Prints the Observer type
  name(type(x))

proc `$`*[T](x: SubjectPtr[T]): string =
  result = $x.observers

