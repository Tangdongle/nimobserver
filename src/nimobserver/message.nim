import macros
from strutils import `%`
from json import JsonNode, `%*`, newJString, newJObject, add, `$`

proc getEnumFieldDefNodes(stmtList: NimNode): seq[NimNode] =
    #[
    Get all the defined fields and their string enum equivalent
    ]#
    expectKind(stmtList, nnkStmtList)
    result = @[]

    for child in stmtList:
        expectKind(child, nnkAsgn)
        result.add(newNimNode(nnkEnumFieldDef).add(child[0]).add(child[1]))

proc createFindSlackRTMTypeProc(typeName: NimIdent, identDefs: seq[NimNode]): NimNode =
    #[
    Build our proc to convert string to these Message Type objects
    ]#
    var msgTypeIdent = newIdentNode("msgType")
    var body = newStmtList()

    body.add(newProc(name = newTree(nnkPostFix, ident("*"), newIdentNode("stringTo$#" % $typeName)),
        params = @[newIdentNode(typeName),
            newIdentDefs(msgTypeIdent, ident("string"))
        ]))

    body[0].body.add(newTree(nnkCaseStmt, msgTypeIdent))
    for identDef in identDefs:
        body[0].body[0].add(newTree(nnkOfBranch,
            newTree(nnkPrefix,
                newIdentNode("$"),
                newTree(nnkDotExpr,
                    newIdentNode(typeName),
                    identDef[0]
                )
            ),
            newStmtList(
                newTree(nnkAsgn,
                    ident("result"),
                    newTree(nnkDotExpr,
                        newIdentNode(typeName),
                        identDef[0]
                    )
                )
            )
        ))
    return body

macro rtmtypes(typeName: untyped, fields: untyped): untyped =
    #[
    As there's many many slack message types, with new ones being added, 
    we want to build an enum from this definition and define a proc
    that translates a string into an Enum 
    ]#
    result = newStmtList()

    result.add(newStmtList(newEnum(
        name = newIdentNode(typeName.ident),
        fields = getEnumFieldDefNodes(fields),
        public = true,
        pure = true)
    ))

    result.add(createFindSlackRTMTypeProc(ident(typeName), getEnumFieldDefNodes(fields)))

rtmtypes SlackRTMType:
    Message = "message"
    UserTyping = "user_typing"
    GroupJoined = "group_joined"
    GroupOpen = "group_open"
    IMCreated = "im_created"
    IMOpen = "im_open"
    Error = "error"
    Test = "test"

type
    BaseMessage* = object of RootObj

    SlackMessage* = object of BaseMessage
        `type`*: SlackRTMType
        channel*: string
        text*: string
        user*: string 
        error: string


proc formatMessageForSend*(message: SlackMessage, msgId: uint): JsonNode =
    #[
    Format a message for slack
    Each message from a connection requires a unique uint so that subsequent messages can respond to it
    ]#
    result = %*
        {
            "id": $msgId,
            "type": $message.type,
            "channel": message.channel,
            "text": message.text
        }
        
proc newSlackMessage(): SlackMessage =
    result.channel = newStringOfCap(254)
    result.text = newStringOfCap(8192)
    result.user = newStringOfCap(254)
    result.error = newStringOfCap(8192)

#proc newSlackMessage(data: JsonNode): SlackMessage =

proc newSlackMessage*(msgType: SlackRTMType, channel, text, user: string): SlackMessage =
    #[
    Creates a new slack message
    msgType: One of the RTM message types: https://api.slack.com/rtm
    channel: A channel ID or direct message ID
    ]#
    result = newSlackMessage()
    result.type = msgType
    result.channel = channel
    result.text = text
    result.user = user
    result.error = nil

proc newSlackErrorMessage*(error: string): SlackMessage =
    result = newSlackMessage()
    result.type = SlackRTMType.Error
    result.error = error

proc hasError*(message: SlackMessage): bool =
    isNil(message.error)

proc newSlackMessage*(msgType, channel, text, user: string): SlackMessage =
    let messageType = stringToSlackRTMType(msgType)
    newSlackMessage(messageType, channel, text, user)

proc `%*`*(message: SlackMessage): JsonNode =
    #[
    Slack message to JSON Node
    ]#
    result = newJObject()
    result.add("type", newJString($message.type))
    result.add("channel", newJString(message.channel))
    result.add("message", newJString(message.text))
    result.add("user", newJString(message.user))

proc `$`*(message: SlackMessage): string =
    $(%*message)

