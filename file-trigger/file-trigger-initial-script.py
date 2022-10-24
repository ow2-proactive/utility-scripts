from os import listdir
from os.path import isfile, join
import time

folderToMonitor = '/tmp/trigger/'
pollTime = 5 #in seconds

#function to return files in a directory
def fileInDirectory(my_dir: str):
    onlyfiles = [f for f in listdir(my_dir) if isfile(join(my_dir, f))]
    return(onlyfiles)

#function comparing two lists
def listComparison(OriginalList: list, NewList: list):
    differencesList = [x for x in NewList if x not in OriginalList] #Note if files get deleted, this will not highlight them
    return(differencesList)

def followupProcess(newFiles: list):
    print('I would do things with file(s)', *newFiles)

def fileWatcher(folderToMonitor: str, pollTime: int):
    while True:
        if variables["previousFileList"] is None: #Check if this is the first time the function has run
            previousFileList = fileInDirectory(folderToMonitor)
            variables["previousFileList"] = previousFileList

        previousFileList = variables["previousFileList"]
        time.sleep(pollTime)
        newFileList = fileInDirectory(folderToMonitor)
        fileDiff = listComparison(previousFileList, newFileList)
        previousFileList = newFileList
        if len(fileDiff) != 0:
            followupProcess(fileDiff)

fileWatcher(folderToMonitor, pollTime)