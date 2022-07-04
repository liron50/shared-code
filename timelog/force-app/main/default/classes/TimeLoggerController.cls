public with sharing class TimeLoggerController {

    @AuraEnabled
    public static Map<String, object> getOpenTimeLog(Id recordId, Map<String, object> params) {
        Map<String, object> retMap = new Map<String, object>();

        String showLogs = String.valueOf(params.get('showLogs'));

        List<Time_Log__c> timelogs = [  SELECT Id,Start__c
                                        FROM Time_Log__c
                                        WHERE Related_Record_Id__c = :recordId
                                        AND OwnerId = :UserInfo.getUserId()
                                        AND Start__c != null
                                        AND End__c = null
                                        LIMIT 1];

        
        retMap.put('openLog', timelogs.isEmpty() ? null : timelogs.get(0));
        retMap.put('oldLogs', showLogs == 'None' ? null : getOldLogs(recordId, showLogs));
        return retMap;
    }

    @AuraEnabled
    public static Map<String, object> startTimer(Id recordId, Map<String, object> params) {
        Map<String, object> retMap = new Map<String, object>();

        Boolean useAssignment = Boolean.valueOf(params.get('useAssignment'));

        if(useAssignment){
            List<Time_Log_Assignment__c> assignments = [SELECT Id,Hours_Left__c,Allow_Exceed_Hours__c
                                                        FROM Time_Log_Assignment__c
                                                        WHERE Related_Record_Id__c = :recordId
                                                        AND User__c = :UserInfo.getUserId()
                                                        AND Hours_Left__c > 0];

            if(assignments.isEmpty()){
                retMap.put('noAssignment', 'You do not have assign hours for this ' + recordId.getSobjectType().getDescribe().getLabel());
            }
        }

        if(! retMap.containsKey('noAssignment')){

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

            retMap.put('openLog', newLog);
        }
        
        return retMap;
    }

    @AuraEnabled
    public static Map<String, object> stopTimer(Id recordId, Id logId, String description, Map<String, object> params) {
        Boolean useAssignment = Boolean.valueOf(params.get('useAssignment'));
        String showLogs = String.valueOf(params.get('showLogs'));

        Time_Log__c updLog = new Time_Log__c(
            Id = logId,
            End__c = System.now(),
            description__c = description
        );
        update updLog;

        if(useAssignment){
            updLog = [  SELECT Total_Hours__c FROM Time_Log__c WHERE Id = :updLog.Id];

            List<Time_Log_Assignment__c> assignments = [SELECT Id,Hours__c,Hours_Left__c,Allow_Exceed_Hours__c,Reported_Hours__c
                                                        FROM Time_Log_Assignment__c
                                                        WHERE Related_Record_Id__c = :recordId
                                                        AND User__c = :UserInfo.getUserId()
                                                        AND Hours_Left__c > 0];
            assignments.get(0).Reported_Hours__c = updLog.Total_Hours__c + (assignments.get(0).Reported_Hours__c > 0 ? assignments.get(0).Reported_Hours__c : 0);

            if(assignments.get(0).Allow_Exceed_Hours__c == false && assignments.get(0).Reported_Hours__c > assignments.get(0).Hours__c){
                assignments.get(0).Reported_Hours__c = assignments.get(0).Hours__c;
            }
            update assignments.get(0);
        }

        return getOpenTimeLog(recordId, params);
    }

    @AuraEnabled
    public static List<Time_Log_Assignment__c> getLogAssignment(Id recordId){
        return [SELECT Id,Hours_Left__c,Allow_Exceed_Hours__c,Reported_Hours__c,User__r.Name,Hours__c
                FROM Time_Log_Assignment__c
                WHERE Related_Record_Id__c = :recordId];
    }

    @AuraEnabled
    public static List<Time_Log_Assignment__c> delAssignmentTimeLog(Id recordId, Id assignmentRecordId) {
        Time_Log_Assignment__c assignment = new Time_Log_Assignment__c(Id = assignmentRecordId);
        delete assignment;

        return getLogAssignment(recordId);
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
