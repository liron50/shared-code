import { LightningElement, track, api } from 'lwc';
import getLogAssignment from '@salesforce/apex/TimeLoggerController.getLogAssignment';
import delAssignmentTimeLog from '@salesforce/apex/TimeLoggerController.delAssignmentTimeLog';

const actions = [
    { label: 'Edit', name: 'edit' },
    { label: 'Delete', name: 'delete' },
];

const columns = [
    { label: 'User', fieldName: 'username' },
    { label: 'Hours', fieldName: 'Hours__c', type: 'number' },
    { label: 'Hours Left', fieldName: 'Hours_Left__c', type: 'number' },
    { type: 'action', typeAttributes: { rowActions: actions },}
];

export default class TimeLoggerAssignments extends LightningElement {
    @api recordId;
    assignmetCol = columns;

    @track logAssignment;
    @track newAssignmentDialog = false;
    @track editAssignmentItem;
    @track loadingComplete = false;
    
    connectedCallback(){
        getLogAssignment({recordId : this.recordId}).then(
            result =>{
                this.setAssignment(result);
                this.loadingComplete = true;
            }
        );  
    }

    addAssignment(){
        this.editAssignmentItem = undefined;
        this.newAssignmentDialog = true;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'delete':
                this.loadingComplete = false;
                delAssignmentTimeLog({recordId: this.recordId, assignmentRecordId: row.Id}).then(
                    result =>{
                        this.setAssignment(result);
                        this.loadingComplete = true;
                    }
                );
                break;
            case 'edit':
                this.editAssignmentItem = row.Id;
                this.newAssignmentDialog = true;
                break;
            default:
        }
    }

    newAssignmentSave(event){
        this.loadingComplete = false;
        event.preventDefault();
        const fields = event.detail.fields;
        fields.Id = this.editAssignmentItem;
        fields.Related_Record_Id__c = this.recordId;
        this.template.querySelector('lightning-record-form').submit(fields);

        setTimeout(() => {
            getLogAssignment({recordId : this.recordId}).then(
                result =>{
                    this.setAssignment(result);
                    this.loadingComplete = true;
                    this.newAssignmentDialog = false;
                }
            );  
        }, 1000);
    }

    closeAssignmentDialog(){
        this.newAssignmentDialog = false;
    }

    setAssignment(res){
        this.logAssignment = res;
        for(let olog in this.logAssignment){
            this.logAssignment[olog].username = this.logAssignment[olog].User__r.Name;
        }
    }
}