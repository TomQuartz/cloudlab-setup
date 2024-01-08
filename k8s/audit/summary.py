#!/usr/bin/env python3

import json
from datetime import datetime
import argparse
import os


def printJsonWithCommonIndent(jsonObj, common=4, indent=4):
    if jsonObj is None:
        return ""
    jsonStr = json.dumps(jsonObj, indent=indent)
    lines = jsonStr.splitlines()
    sep = "\n" + " " * common
    return sep.join(lines)


def getJsonFieldOrNone(jsonObj, *paths, common=4, indent=4):
    if len(paths) == 0:
        return jsonObj, ""
    prefix = []
    for field in paths:
        try:
            jsonObj = jsonObj[field]
            prefix.append(field)
        except KeyError:
            break
    prefix = ".".join(prefix)
    if len(prefix) > 0:
        return prefix + ": " + printJsonWithCommonIndent(jsonObj, common, indent)
    return ""


def getElapsedTimeMilli(timeDelta):
    return timeDelta.days*24*60*60*1000 + timeDelta.seconds*1000 + timeDelta.microseconds/1000


def parseEventSince(jsonPath: str, since: str, timeFormat: str = "%Y-%m-%dT%H:%M:%S.%fZ"):
    with open(jsonPath) as f:
        contents = f.read()
        contents = contents.replace('}\n{', '},\n{')
        events = json.loads('[\n'+contents+'\n]')
    cutOff = datetime.strptime(since, timeFormat)
    history = {}
    for event in events:
        receivedTime = datetime.strptime(
            event["requestReceivedTimestamp"], timeFormat)

        if receivedTime < cutOff:
            continue
        try:
            receivedTimeRel = getElapsedTimeMilli(receivedTime - cutOff)
            stageTimeRel = getElapsedTimeMilli(datetime.strptime(
                event["stageTimestamp"], timeFormat)-receivedTime)
            history[receivedTime] = f"""
requestURI: {event["requestURI"]}
    verb: {event["verb"]}
    {getJsonFieldOrNone(event, "user", "username")}
    requestReceivedTimestamp[{receivedTimeRel:.3f}]: {event["requestReceivedTimestamp"]}
    stageTimestamp[+{stageTimeRel:.3f}]: {event["stageTimestamp"]}
    {getJsonFieldOrNone(event, "requestObject", "status")}"""

        except KeyError:
            print(event["requestReceivedTimestamp"])
    return history


def main():
    parser = argparse.ArgumentParser(description='Parse a list of json files.')
    parser.add_argument('-d', '--root', type=str, default=".")
    parser.add_argument('jsonPath', type=str, nargs='+',
                        help='path to the json file')
    parser.add_argument('-s', '--since', type=str, default="2024-01-01T00:00:00.000Z",
                        help='only show events since this time')
    args = parser.parse_args()
    fullHistory = {}
    for jsonPath in args.jsonPath:
        fullPath = os.path.join(args.root, jsonPath)
        print(f"reading {jsonPath}")
        history = parseEventSince(fullPath, args.since)
        fullHistory.update(history)
    for eventTime in sorted(fullHistory.keys()):
        print(fullHistory[eventTime])


if __name__ == "__main__":
    main()
