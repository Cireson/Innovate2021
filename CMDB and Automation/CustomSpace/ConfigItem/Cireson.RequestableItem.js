{   
    "Default":
    {
        tabList: [
            /*********/
            /** TAB **/
            /*********/
            {
                name: "General",
                content: [
                    {
                        customFieldGroupList: [
                            {
                                name: "Requestable Item",
                                rows: [
                                    {
                                        columnFieldList: [
                                            { DataType: "String", PropertyDisplayName: "Name", PropertyName: "Name", Required: true },
                                            { DataType: "ObjectPicker", PropertyDisplayName: "AssociatedConfigurationItem", PropertyName: "HasAssociatedCI", ClassId: "62F0BE9F-ECEA-E73C-F00D-3DD78A7422FC", Disabled: false },                                            
                                            { DataType: "String", PropertyDisplayName: "AD Group for Access", PropertyName: "AccessGroup", Required: true, MinLength: 0, MaxLength: 200 }
                                        ]
                                    },
                                    {
                                        columnFieldList: [
                                            { DataType: "Enum", PropertyDisplayName: "Type", PropertyName: "Type", EnumId: '8764f3b1-14b0-b376-5d14-db6c9ccb65d6' },
                                            { DataType: "Enum", PropertyDisplayName: "Status", PropertyName: "Status", EnumId: '78f63e64-e80c-b5d3-43be-f7b6a2a21748' },
                                            { DataType: "Spacer" }
                                        ]
                                    }
                                ]
                            },
                            {
                                name: "Approval",
                                rows: [
                                    {
                                        columnFieldList: [
                                            { DataType: "Enum", PropertyDisplayName: "First Approver", PropertyName: "FirstApprover", Required: true, EnumId: '7a1b7575-acff-292d-aefc-d04225e43f34' },
                                            { DataType: "Enum", PropertyDisplayName: "Second Approver", PropertyName: "SecondApprover", Required: true, EnumId: '7a1b7575-acff-292d-aefc-d04225e43f34' },
                                            { DataType: "Spacer" }
                                        ]
                                    }
                                ]
                            },
                            {
                                name: "Approvers",
                                rows: [
                                    {
                                        columnFieldList: [
                                            {
                                                name: "",
                                                type: "multipleObjectPicker",
                                                PropertyName: "HasApprovers",
                                                ClassId: "10A7F898-E672-CCF3-8881-360BFB6A8F9A",
                                                Scoped: false,
                                                Disabled: false,
                                                PropertyToDisplay: { DisplayName: "DisplayName", UserName: "UserName" },
                                                SelectableRow: false,
                                                SelectableProperty: "DisplayName"
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    }
                ]
            },
            /*********/
            /** TAB **/
            /*********/
            {
                name: "Users",
                content: [
                    {
                        customFieldGroupList: [
                            {
                                name: "Users Given",
                                rows: [
                                    {
                                        columnFieldList: [
                                            {
                                                name: "",
                                                type: "multipleObjectPicker",
                                                PropertyName: "GivenToUsers",
                                                ClassId: "10A7F898-E672-CCF3-8881-360BFB6A8F9A",
                                                Scoped: false,
                                                Disabled: true,
                                                PropertyToDisplay: { DisplayName: "DisplayName", UserName: "UserName" },
                                                SelectableRow: false,
                                                SelectableProperty: "DisplayName"
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    }
                ]
            },
            /*********/
            /** TAB **/
            /*********/
            {
                name: "RelatedItems",
                content: [
                    {
                        customFieldGroupList: [
                            {
                                name: "WIAffectCI",
                                rows: [
                                    {
                                        columnFieldList: [
                                            {
                                                name: "",
                                                type: "multipleObjectPicker",
                                                PropertyName: "IsAboutConfigItems",
                                                ClassId: "F59821E2-0364-ED2C-19E3-752EFBB1ECE9",
                                                Disabled: false,
                                                PropertyToDisplay: { Id: "Id", Title: "Title", "Status.Name": "Status", LastModified: "LastModified" },
                                                SelectableRow: true,
                                                SelectProperty: "Id"
                                            }
                                        ],
                                    }
                                ]
                            },
                            {
                                name: "WorkItems",
                                rows: [
                                    {
                                        columnFieldList: [
                                            {
                                                name: "",
                                                type: "multipleObjectPicker",
                                                PropertyName: "RelatesToWorkItem",
                                                ClassId: "F59821E2-0364-ED2C-19E3-752EFBB1ECE9",
                                                Disabled: false,
                                                PropertyToDisplay: { Id: "Id", Title: "Title", "Status.Name": "Status", LastModified: "LastModified" },
                                                SelectableRow: true,
                                                SelectProperty: "Id"
                                            }
                                        ],
                                    }
                                ]
                            },
                            {
                                name: "CIComputerService",
                                rows: [
                                    {
                                        columnFieldList: [
                                            {
                                                name: "",
                                                type: "multipleObjectPicker",
                                                PropertyName: "TargetConfigItem",
                                                ClassId: "62F0BE9F-ECEA-E73C-F00D-3DD78A7422FC",
                                                Disabled: false,
                                                PropertyToDisplay: { DisplayName: "DisplayName", FullClassName: "Type", "ObjectStatus.Name": "ObjectStatus", LastModified: "LastModified" },
                                                SelectableRow: true,
                                                SelectProperty: "DisplayName"
                                            }
                                        ],
                                    }
                                ]
                            },
                            {
                                name: "KnowledgeArticles",
                                rows: [
                                    {
                                        columnFieldList: [
                                            {
                                                name: "",
                                                type: "multipleObjectPicker",
                                                PropertyName: "KnowledgeDocument",
                                                ClassId: "CA1410D8-6182-1531-092B-D2232F396BB8",
                                                Disabled: false,
                                                PropertyToDisplay: { ArticleId: "ArticleId", Title: "Title", Type: "Type", LastModified: "LastModified" },
                                                SelectableRow: true,
                                                SelectProperty: "Id"
                                            }
                                        ],
                                    }
                                ]
                            },
                            {
                                name: "FileAttachments",
                                type: "fileAttachments"
                            }
                        ]
                    }
                ]
            },
            /*********/
            /** TAB **/
            /*********/
            {
                name: "History",
                content: [
                    {
                        customFieldGroupList: [
                            {
                                name: "History",
                                type: "history"
                            }
                        ]
                    }
                ]
            }
        ]
    }
}
