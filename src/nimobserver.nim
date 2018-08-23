# messagebus
# Copyright Ryanc_signiq
# A message event queue implementation
from threadpool import spawn
from os import sleep
from typetraits import name

type
  BaseObserver* = ref object of RootObj

  Subject*[T] = object of RootObj
    observers: seq[BaseObserver]
    channel: Channel[T]

  SubjectPtr*[T] = ptr Subject[T]

method onNotify[T](observer: BaseObserver, message: T) {.base gcsafe.} = 
  echo "Base Notification:: Data value: " & $message

method notify[T](subject: SubjectPtr[T], notification: T) {.base gcsafe.} =
  for observer in subject.observers:
    observer.onNotify(notification[])

method update[T](subject: SubjectPtr[T]) {.base thread.} =
  while true:
    let msg = recv(subject.channel)
    subject.notify(msg)
    echo "Sleeping"
    sleep(300)

method publish*[T](subject: SubjectPtr[T], message: T) {.base.} =
  #[
  Send our message through our channel, which will notify any observers
  ]#
  subject.channel.send message

method addObserver*[T](subject: SubjectPtr[T], observer: BaseObserver) {.base.} =
  subject.observers.add(observer)

method removeObserver*[T](subject: SubjectPtr[T], observer: BaseObserver) {.base.} =
  assert subject.observers.contains(observer)
  subject.observers.delete(subject.observers.find(observer))

proc newSubject*[T](): SubjectPtr[T] =
  result = createShared(Subject[T])
  result.observers = @[]
  open(result.channel)

proc initSubject*[T](): SubjectPtr[T] =
  result = newSubject[T]()
  spawn result.update()

proc `$`*(x: BaseObserver): string =
  name(type(x))

proc `$`*[T](x: SubjectPtr[T]): string =
  result = $x.observers

#let globalTestSub: SubjectPtr[SlackMessagePtr] = newSubject[SlackMessagePtr]()
#spawn globalTestSub.update()

