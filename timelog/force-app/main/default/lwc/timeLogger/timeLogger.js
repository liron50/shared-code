import { LightningElement, track, api } from 'lwc';
import LightningPrompt from 'lightning/prompt';
import getOpenTimeLog from '@salesforce/apex/TimeLoggerController.getOpenTimeLog';
import startTimer from '@salesforce/apex/TimeLoggerController.startTimer';
import stopTimer from '@salesforce/apex/TimeLoggerController.stopTimer';

const columns = [
    { label: 'Reported By', fieldName: 'username' },
    { label: 'Start', fieldName: 'Start__c', type: 'date' , typeAttributes:{year: "numeric",month: "long",day: "2-digit",hour: "2-digit",minute: "2-digit"}},
    { label: 'End', fieldName: 'End__c', type: 'date', typeAttributes:{year: "numeric",month: "long",day: "2-digit",hour: "2-digit",minute: "2-digit"}},
    { label: 'Description', fieldName: 'Description__c' }
];

export default class TimeLogger extends LightningElement {
    @api recordId;
    @api showLogs = 'Current User';
    @track logRecord;
    @track showOldLogs = false;
    @track oldLogs;
    @track loadingComplete = false;

    @track runningLogTime;
    @track logSeconds;
    @track logMinutes;
    @track logHours;

    oldLogsCol = columns;
    runningInterval

    connectedCallback(){

        getOpenTimeLog({recordId : this.recordId, showLogs: this.showLogs}).then(
            result =>{
                this.logRecord = result.openLog;
                this.oldLogs = result.oldLogs;
                this.setOldLogs();
                this.setCurrentLogTime();
                this.loadingComplete = true;
            }
        );        
    }

    startLogTimer(){
        this.loadingComplete = false;
        startTimer({recordId: this.recordId, showLogs: this.showLogs}).then(
            result =>{
                this.logRecord = result.openLog;
                this.oldLogs = result.oldLogs;
                this.setOldLogs();
                this.setCurrentLogTime();
                this.loadingComplete = true;
            }
        );
    }

    stopLogTimer(){
        LightningPrompt.open({
            message: 'Add Description',
            labe: 'Description'
        }).then(
            (result) =>{
                this.loadingComplete = false;

                stopTimer({recordId: this.recordId, logId: this.logRecord.Id, description: result, showLogs: this.showLogs}).then(
                    result =>{
                        this.logRecord = undefined;
                        this.oldLogs = result.oldLogs;
                        this.setOldLogs();
                        this.setCurrentLogTime();
                        clearInterval(this.runningInterval);
                        this.loadingComplete = true;
                    }
                );
            }
        );
    }

    setOldLogs(){
        this.showOldLogs = this.oldLogs != undefined && this.oldLogs.length > 0; 
        
        for(let olog in this.oldLogs){
            this.oldLogs[olog].username = this.oldLogs[olog].Owner.Name;
        }
    }

    setCurrentLogTime(){
        
        if(this.logRecord){
            let date1 = new Date()
            let date2 = new Date(this.logRecord.Start__c)

            //you get the difference in ms
            let currentLogTiming = Math.abs(date1.valueOf()-date2.valueOf())

            this.logHours = Math.floor(currentLogTiming/1000/60/60);
            this.logMinutes = Math.floor((currentLogTiming/1000/60) % 60);
            this.logSeconds = Math.floor((currentLogTiming/1000) % 60);

            this.runningLogTime = 
                    this.logHours + ':' + 
                    (this.logMinutes < 10 ? '0' + this.logMinutes : this.logMinutes) + ':' + 
                    (this.logSeconds < 10 ? '0' + this.logSeconds : this.logSeconds);

            this.runningInterval = setInterval(
                function(){ 
                    this.logSeconds ++;
                    console.log('currentSeconds:: ' + this.logSeconds);
                    
                    if(this.logSeconds == 60){
                        this.logSeconds = 0;
                        this.logMinutes ++; 

                        if(this.logMinutes == 60){
                            this.logMinutes = 0;
                            this.logHours ++; 
                        }
                    }

                    this.runningLogTime = 
                        this.logHours + ':' + 
                        (this.logMinutes < 10 ? '0' + this.logMinutes : this.logMinutes) + ':' + 
                        (this.logSeconds < 10 ? '0' + this.logSeconds : this.logSeconds);
            }.bind(this), 1000);
        }
    }
}