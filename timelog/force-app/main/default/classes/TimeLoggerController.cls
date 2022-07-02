public with sharing class TimeLoggerController {
    @AuraEnabled
    public static Map<String, object> getOpenTimeLog(Id recordId, String showLogs) {

        List<Time_Log__c> timelogs = [  SELECT Id,Start__c
                                        FROM Time_Log__c
                                        WHERE Related_Record_Id__c = :recordId
                                        AND OwnerId = :UserInfo.getUserId()
                                        AND Start__c != null
                                        AND End__c = null
                                        LIMIT 1];

        Map<String, object> retMap = new Map<String, object>();
        retMap.put('openLog', timelogs.isEmpty() ? null : timelogs.get(0));
        retMap.put('oldLogs', showLogs == 'None' ? null : getOldLogs(recordId, showLogs));
        return retMap;
    }

    @AuraEnabled
    public static Map<String, object> startTimer(Id recordId, String showLogs) {
        Time_Log__c newLog = new Time_Log__c(
            Start__c = System.now(),
            Related_Record_Id__c = recordId
        );

        //Search for lookup that match the object type for recordId in the object Time_Log__c
        String objectType = recordId.getSobjectType().getDescribe().getName();
        Schema.SObjectType objSchema = Schema.getGlobalDescribe().get('Time_Log__c');
        Map<String, Schema.SObjectField> fieldMap = objSchema.getDescribe().fields.getMap();//This has the list of all field names.

        for(Schema.SObjectfield field : fieldMap.values()){
            Schema.DescribeFieldResult dfr = field.getDescribe();

            if(dfr.getType() == Schema.DisplayType.REFERENCE && dfr.getName().endsWith('__c')){
                set<String> sTypes = new set<String>();

                for(Schema.SObjectType refTo : dfr.getReferenceTo()){
                    sTypes.add(refTo.getDescribe().getName());
                }

                if(sTypes.contains(objectType)){
                    newLog.put(dfr.getName(), recordId);
                }
            }
        }

        insert newLog;

        Map<String, object> retMap = new Map<String, object>();
        retMap.put('openLog', newLog);
        retMap.put('oldLogs', showLogs == 'None' ? null : getOldLogs(recordId, showLogs));
        return retMap;
    }

    @AuraEnabled
    public static Map<String, object> stopTimer(Id recordId, Id logId, String description, String showLogs) {

        Time_Log__c updLog = new Time_Log__c(
            Id = logId,
            End__c = System.now(),
            description__c = description
        );
        update updLog;

        Map<String, object> retMap = new Map<String, object>();
        retMap.put('openLog', null);
        retMap.put('oldLogs', showLogs == 'None' ? null : getOldLogs(recordId, showLogs));
        return retMap;
    }

    private static List<Time_Log__c> getOldLogs(Id recordId, String showLogs){

        String queryStr = 'SELECT Id,Owner.Name,Start__c, End__c, Description__c FROM Time_Log__c WHERE Related_Record_Id__c = \'' + recordId + '\' AND End__c != null';

        if(showLogs == 'Current User'){
            queryStr += ' AND OwnerId = \'' + UserInfo.getUserId()  + '\'';
        }

        queryStr += ' ORDER BY CreatedDate Desc';

        return Database.query(queryStr);
    }
}
