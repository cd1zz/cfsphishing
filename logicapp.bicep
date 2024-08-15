param region string = 'eastus'
param logicAppName string = 'CopilotForSecurityPhishingAnalysisTemplate'
param office365ConnectionName string = 'office365-1'
param securityCopilotConnectionName string = 'securitycopilot-2'
param subscriptionId string
param resourceGroupName string
param functionAppName string

resource office365ApiConnection 'Microsoft.Web/connections@2021-06-01' = {
  name: office365ConnectionName
  location: region
  properties: {
    api: {
      id: resourceId('Microsoft.Web/locations', 'office365')
    }
    displayName: 'Office 365'
  }
}

resource securityCopilotApiConnection 'Microsoft.Web/connections@2021-06-01' = {
  name: securityCopilotConnectionName
  location: region
  properties: {
    api: {
      id: resourceId('Microsoft.Web/locations', 'securitycopilot')
    }
    displayName: 'Security Copilot'
  }
}

resource logicApp 'Microsoft.Logic/workflows@2017-07-01' = {
  name: logicAppName
  location: region
  properties: {
    state: 'Disabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        'When_a_new_email_arrives_(V3)': {
          splitOn: '@triggerBody()?[\'value\']'
          type: 'ApiConnectionNotification'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365-1\'][\'connectionId\']'
              }
            }
            fetch: {
              pathTemplate: {
                template: '/v3/Mail/OnNewEmail'
              }
              method: 'get'
              queries: {
                importance: 'Any'
                fetchOnlyWithAttachment: false
                includeAttachments: true
                folderPath: 'Inbox'
              }
            }
            subscribe: {
              body: {
                NotificationUrl: '@{listCallbackUrl()}'
              }
              pathTemplate: {
                template: '/GraphMailSubscriptionPoke/$subscriptions'
              }
              method: 'post'
              queries: {
                importance: 'Any'
                fetchOnlyWithAttachment: false
                folderPath: 'Inbox'
              }
            }
          }
        }
      }
      actions: {
        Check_if_attachments_exist: {
          actions: {
            'Copilot_for_Security_-_Check_Attachment_Reputation': {
              type: 'ApiConnection'
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'securitycopilot-1\'][\'connectionId\']'
                  }
                }
                method: 'post'
                body: {
                  PromptContent: '{"hash": "@{body(\'Parse_JSON_from_functionapp\')?[\'email_content\']?[\'attachments\'][0]?[\'attachment_sha256\']}"}'
                  SessionId: '@body(\'Copilot_for_Security_-_Analyze_Email_Intent\')?[\'sessionId\']'
                  SkillName: 'GetFileAnalysis'
                }
                path: '/process-prompt'
              }
            }
          }
          runAfter: {
            'Copilot_for_Security_-_Analyze_Email_Intent': [
              'Succeeded'
            ]
          }
          else: {
            actions: {}
          }
          expression: {
            and: [
              {
                greater: [
                  '@length(body(\'Parse_JSON_from_functionapp\')?[\'email_content\']?[\'attachments\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Check_if_domains_and_urls: {
          actions: {
            'For_each_domain_or_url_-_one_thread_at_a_time': {
              foreach: '@variables(\'domains_and_urls\')'
              actions: {
                'Compose_debug_-_show_url_or_domain': {
                  type: 'Compose'
                  inputs: '@items(\'For_each_domain_or_url_-_one_thread_at_a_time\')'
                }
                HTTP_virustotal_GET: {
                  runAfter: {
                    'Compose_debug_-_show_url_or_domain': [
                      'Succeeded'
                    ]
                  }
                  type: 'Http'
                  inputs: {
                    uri: 'https://www.virustotal.com/api/v3/urls/@{replace(base64(items(\'For_each_domain_or_url_-_one_thread_at_a_time\')), \'=\', \'\')}'
                    method: 'GET'
                    headers: {
                      'Content-Type': 'application/json'
                      'x-apikey': 'PLACEHOLDER'
                    }
                    retryPolicy: {
                      type: 'fixed'
                      count: 3
                      interval: 'PT10S'
                    }
                  }
                  runtimeConfiguration: {
                    contentTransfer: {
                      transferMode: 'Chunked'
                    }
                  }
                }
                Continue_loop_if_VT_has_404_on_url: {
                  actions: {}
                  runAfter: {
                    HTTP_virustotal_GET: [
                      'Succeeded'
                    ]
                  }
                  else: {
                    actions: {
                      For_each_threat_name_add_to_array: {
                        foreach: '@body(\'Parse_JSON_from_VirusTotal\')?[\'data\']?[\'attributes\']?[\'threat_names\']'
                        actions: {
                          Append_to_threat_names_array: {
                            type: 'AppendToArrayVariable'
                            inputs: {
                              name: 'threat_names'
                              value: '@items(\'For_each_threat_name_add_to_array\')'
                            }
                          }
                        }
                        runAfter: {
                          Parse_JSON_from_VirusTotal: [
                            'Succeeded'
                          ]
                        }
                        type: 'Foreach'
                      }
                      Parse_JSON_from_VirusTotal: {
                        type: 'ParseJson'
                        inputs: {
                          content: '@body(\'HTTP_virustotal_GET\')'
                          schema: {
                            properties: {
                              data: {
                                properties: {
                                  attributes: {
                                    properties: {
                                      last_analysis_results: {
                                        type: 'object'
                                        additionalProperties: {
                                          type: 'object'
                                          properties: {
                                            method: {
                                              type: 'string'
                                            }
                                            engine_name: {
                                              type: 'string'
                                            }
                                            category: {
                                              type: 'string'
                                            }
                                            result: {
                                              type: 'string'
                                            }
                                          }
                                        }
                                      }
                                      last_analysis_stats: {
                                        properties: {
                                          harmless: {
                                            type: 'integer'
                                          }
                                          malicious: {
                                            type: 'integer'
                                          }
                                          suspicious: {
                                            type: 'integer'
                                          }
                                          undetected: {
                                            type: 'integer'
                                          }
                                        }
                                        type: 'object'
                                      }
                                      threat_names: {
                                        items: {
                                          type: 'string'
                                        }
                                        type: 'array'
                                      }
                                    }
                                    type: 'object'
                                  }
                                  id: {
                                    type: 'string'
                                  }
                                  type: {
                                    type: 'string'
                                  }
                                }
                                type: 'object'
                              }
                            }
                            type: 'object'
                          }
                        }
                      }
                      Set_variable_domain_malicious_count: {
                        runAfter: {
                          Parse_JSON_from_VirusTotal: [
                            'Succeeded'
                          ]
                        }
                        type: 'SetVariable'
                        inputs: {
                          name: 'domain_malicious_count'
                          value: '@body(\'Parse_JSON_from_VirusTotal\')?[\'data\']?[\'attributes\']?[\'last_analysis_stats\']?[\'malicious\']'
                        }
                      }
                      Did_we_find_known_malicious_url_or_domain: {
                        actions: {
                          Set_variable_has_malicious_domain_or_url: {
                            runAfter: {
                              Compose_for_debugging_malicious_domain_true: [
                                'Succeeded'
                              ]
                            }
                            type: 'SetVariable'
                            inputs: {
                              name: 'has_malicious_domain'
                              value: true
                            }
                          }
                          Compose_for_debugging_malicious_domain_true: {
                            runAfter: {
                              'ParseEmailVT-parse_virustotal_json': [
                                'Succeeded'
                              ]
                            }
                            type: 'Compose'
                            inputs: '@outputs(\'ParseEmailVT-parse_virustotal_json\')'
                          }
                          Set_variable_last_analysis_results: {
                            runAfter: {
                              Set_variable_has_malicious_domain_or_url: [
                                'Succeeded'
                              ]
                            }
                            type: 'SetVariable'
                            inputs: {
                              name: 'last_analysis_results'
                              value: '@{outputs(\'ParseEmailVT-parse_virustotal_json\')}'
                            }
                          }
                          'ParseEmailVT-parse_virustotal_json': {
                            type: 'Function'
                            inputs: {
                              body: '@body(\'Parse_JSON_from_VirusTotal\')'
                              function: {
                                id: '${resourceId('Microsoft.Web/sites', functionAppName)}/functions/parse_virustotal_json'
                              }
                            }
                          }
                        }
                        runAfter: {
                          Set_variable_domain_malicious_count: [
                            'Succeeded'
                          ]
                        }
                        else: {
                          actions: {
                            Compose_for_debugging_malicious_domain_false: {
                              type: 'Compose'
                              inputs: '@variables(\'domain_malicious_count\')'
                            }
                          }
                        }
                        expression: {
                          and: [
                            {
                              greater: [
                                '@variables(\'domain_malicious_count\')'
                                0
                              ]
                            }
                          ]
                        }
                        type: 'If'
                      }
                    }
                  }
                  expression: {
                    and: [
                      {
                        equals: [
                          '@outputs(\'HTTP_virustotal_GET\')?[\'statusCode\']'
                          404
                        ]
                      }
                    ]
                  }
                  type: 'If'
                }
              }
              type: 'Foreach'
              runtimeConfiguration: {
                concurrency: {
                  repetitions: 1
                }
              }
            }
          }
          runAfter: {
            Initialize_variable_attachments: [
              'Succeeded'
            ]
          }
          else: {
            actions: {}
          }
          expression: {
            and: [
              {
                greater: [
                  '@length(variables(\'domains_and_urls\'))'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Compose_combine_urls_and_domain_array: {
          runAfter: {
            Initialize_variable_has_malicious_domain: [
              'Succeeded'
            ]
          }
          type: 'Compose'
          inputs: '@union(variables(\'domains\'),variables(\'urls\'))'
        }
        'Export_email_(V2)': {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365-1\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/codeless/beta/me/messages/@{encodeURIComponent(triggerBody()?[\'id\'])}/$value'
          }
        }
        For_each_attachment: {
          foreach: '@triggerBody()?[\'attachments\']'
          actions: {
            if_MSG_binary_attachment: {
              actions: {
                Base64_ContentBytes_decode: {
                  type: 'Compose'
                  inputs: '@base64ToBinary(items(\'For_each_attachment\')?[\'contentBytes\'])'
                }
                Set_variable_raw_email_msg_binary_decoded: {
                  runAfter: {
                    Base64_ContentBytes_decode: [
                      'Succeeded'
                    ]
                  }
                  type: 'SetVariable'
                  inputs: {
                    name: 'raw_email'
                    value: '@{outputs(\'Base64_ContentBytes_decode\')}'
                  }
                }
              }
              else: {
                actions: {}
              }
              expression: {
                or: [
                  {
                    equals: [
                      '@item()?[\'contentType\']'
                      'application/vnd.ms-outlook'
                    ]
                  }
                  {
                    equals: [
                      '@item()?[\'contentType\']'
                      'application/octet-stream'
                    ]
                  }
                ]
              }
              type: 'If'
            }
          }
          runAfter: {
            Initialize_and_set_variable_raw_email: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        Has_known_malicious_domain_or_url: {
          actions: {
            'Copilot_for_Security_-_Finalize_and_Score_-_Has_known_malicious': {
              type: 'ApiConnection'
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'securitycopilot-1\'][\'connectionId\']'
                  }
                }
                method: 'post'
                body: {
                  PromptContent: '/AskGpt Summarize our phishing email investigation to determine the legitimacy of the email, with a focus on identified malicious domains.\n\nInvestigation Summary Steps (analyze the available data points):\n1. Attachments: If present, evaluate the attachments for potential malware or unusual file types. Verify the legitimacy of the attachment source. Attachment analysis was performed in a previous prompt in this session. \n2. Domains and urls: Inspect the domains and urls for spelling variations or minor differences from legitimate domains. Check if the domain is newly registered, has a suspicious history, or is marked as malicious from VirusTotal. Here are the domains and urls extracted: @{variables(\'domains_and_urls\')}\n3. Email Body Intent: Assess the email body for signs of phishing, such as a sense of urgency, requests for personal information, strange requests, attempting to get the user to open a link or an attachment, and any malicious or suspicious links. \n\nCriteria for Evaluation:\n- Focus on domains and urls identified as malicious during the investigation. Highlight any domains that are very closely spelled to real domains, indicating an attempt to deceive the user. Here is the output from VirusTotal regarding the domain:\n\n1. Number of security vendors marking as \'malicious\': @{variables(\'domain_malicious_count\')} \n2. Threat names provided by security vendors: @{variables(\'threat_names\')}  \n3. Reasons for domain or url marked as malicious: @{variables(\'last_analysis_results\')}\n\nFinal Decision:\n- Provide a confidence score from 0-100 where 0 indicates the email is not likely a phishing email and 100 indicates the email is definitely a phishing email.\n- Provide evidence for your decision to support the confidence score, specifically highlighting the impact of malicious domains found.\n- The higher the number, the more likely it is a phishing email.\n- Include detailed evidence and reasoning behind the confidence score, emphasizing the role of malicious domains and email intent in your analysis.'
                  SessionId: '@body(\'Copilot_for_Security_-_Analyze_Email_Intent\')?[\'sessionId\']'
                }
                path: '/process-prompt'
              }
            }
            Parse_JSON: {
              runAfter: {
                'Copilot_for_Security_-_Finalize_and_Score_-_Has_known_malicious': [
                  'Succeeded'
                ]
              }
              type: 'ParseJson'
              inputs: {
                content: '@body(\'Copilot_for_Security_-_Finalize_and_Score_-_Has_known_malicious\')'
                schema: {
                  properties: {
                    'Evaluation Result Content': {
                      type: 'string'
                    }
                    'Evaluation Result Type': {
                      type: 'string'
                    }
                    'Prompt Content': {
                      type: 'string'
                    }
                    SessionId: {
                      type: 'string'
                    }
                    'Skill Name': {
                      type: 'string'
                    }
                    'Skill Sources': {
                      type: 'array'
                    }
                  }
                  type: 'object'
                }
              }
            }
          }
          runAfter: {
            Check_if_attachments_exist: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              'Copilot_for_Security_-_Finalize_and_Score_-_Does_not_have_known_malicious': {
                type: 'ApiConnection'
                inputs: {
                  host: {
                    connection: {
                      name: '@parameters(\'$connections\')[\'securitycopilot-1\'][\'connectionId\']'
                    }
                  }
                  method: 'post'
                  body: {
                    PromptContent: '/AskGpt Summarize our phishing email investigation to determine the legitimacy of the email. Although no malicious domains were found, analyze other data points for conclusive insights.\n\nInvestigation Summary Steps (analyze the available data points):\n1. Attachments: If present, evaluate the attachments for potential malware or unusual file types. Verify the legitimacy of the attachment source. Attachment analysis was performed in a previous prompt in this session. \n2. Domains and urls: Inspect the domains and urls for spelling variations or minor differences from legitimate domains. Note that no domains were found to be malicious from VirusTotal, but check for any other suspicious characteristics. Here are the domains and urls extracted from the email: @{variables(\'domains_and_urls\')}\n3. Email Body Intent: Assess the email body for signs of phishing, such as a sense of urgency, requests for personal information, strange requests, attempting to get the user to open a link or an attachment. \n\nCriteria for Evaluation:\n- Since no malicious domains or urls were found, base your conclusions on other indicators of phishing, such as attachments, and most importantly email body intent.\n- Consider if domains are very closely spelled to real domains, indicating an attempt to deceive the user.\n\nFinal Decision:\n- Provide a confidence score from 0-100 where 0 indicates the email is not likely a phishing email and 100 indicates the email is definitely a phishing email.\n- Provide evidence for your decision to support the confidence score, focusing on non-domain data points due to the absence of malicious domains.\n- The higher the number, the more likely it is a phishing email.\n- Include detailed evidence and reasoning behind the confidence score, based on other investigation data points.'
                    SessionId: '@body(\'Copilot_for_Security_-_Analyze_Email_Intent\')?[\'sessionId\']'
                  }
                  path: '/process-prompt'
                }
              }
              'Parse_JSON-copy': {
                runAfter: {
                  'Copilot_for_Security_-_Finalize_and_Score_-_Does_not_have_known_malicious': [
                    'Succeeded'
                  ]
                }
                type: 'ParseJson'
                inputs: {
                  content: '@body(\'Copilot_for_Security_-_Finalize_and_Score_-_Does_not_have_known_malicious\')'
                  schema: {
                    properties: {
                      evaluationResultContent: {
                        type: 'string'
                      }
                      evaluationResultType: {
                        type: 'string'
                      }
                      promptContent: {
                        type: 'string'
                      }
                      sessionId: {
                        type: 'string'
                      }
                      skillName: {
                        type: 'string'
                      }
                      skillSources: {
                        type: 'array'
                      }
                    }
                    type: 'object'
                  }
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@variables(\'has_malicious_domain\')'
                  true
                ]
              }
            ]
          }
          type: 'If'
        }
        Initialize_and_set_variable_raw_email: {
          runAfter: {
            'Export_email_(V2)': [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'raw_email'
                type: 'string'
                value: '@{body(\'Export_email_(V2)\')}'
              }
            ]
          }
        }
        Initialize_variable_domain_malicious_count: {
          runAfter: {
            Initialize_variable_threat_names: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'domain_malicious_count'
                type: 'integer'
              }
            ]
          }
        }
        Initialize_variable_domains: {
          runAfter: {
            Initialize_variable_urls: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'domains'
                type: 'array'
                value: '@body(\'Parse_JSON_from_functionapp\')?[\'domains\']'
              }
            ]
          }
        }
        Initialize_variable_domains_and_urls: {
          runAfter: {
            Initialize_variable_domains: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'domains_and_urls'
                type: 'array'
              }
            ]
          }
        }
        Initialize_variable_has_malicious_domain: {
          runAfter: {
            Initialize_variable_domain_malicious_count: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'has_malicious_domain'
                type: 'boolean'
                value: false
              }
            ]
          }
        }
        Initialize_variable_malicious_results: {
          runAfter: {
            Set_variable_domains_and_urls: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'malicious_results'
                type: 'array'
              }
            ]
          }
        }
        Initialize_variable_threat_names: {
          runAfter: {
            Initialize_variable_domains_and_urls: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'threat_names'
                type: 'array'
              }
            ]
          }
        }
        Initialize_variable_urls: {
          runAfter: {
            Parse_JSON_from_functionapp: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'urls'
                type: 'array'
                value: '@body(\'Parse_JSON_from_functionapp\')?[\'urls\']'
              }
            ]
          }
        }
        Parse_JSON_from_functionapp: {
          runAfter: {
            'ParseEmailVT-parse_email': [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'ParseEmailVT-parse_email\')'
            schema: {
              properties: {
                domains: {
                  items: {
                    type: 'string'
                  }
                  type: 'array'
                }
                email_content: {
                  properties: {
                    attachments: {
                      type: 'array'
                    }
                    body: {
                      type: 'string'
                    }
                    date: {
                      type: 'string'
                    }
                    dkim_result: {
                      type: 'string'
                    }
                    dmarc_result: {
                      type: 'string'
                    }
                    receiver: {
                      type: 'string'
                    }
                    reply_to: {
                      type: 'string'
                    }
                    return_path: {
                      type: 'string'
                    }
                    sender: {
                      type: 'string'
                    }
                    smtp: {
                      properties: {
                        delivered_to: {
                          type: 'string'
                        }
                        received: {
                          items: {
                            type: 'string'
                          }
                          type: 'array'
                        }
                      }
                      type: 'object'
                    }
                    spf_result: {
                      type: 'string'
                    }
                    subject: {
                      type: 'string'
                    }
                  }
                  type: 'object'
                }
                ip_addresses: {
                  items: {
                    type: 'string'
                  }
                  type: 'array'
                }
                urls: {
                  type: 'array'
                }
              }
              type: 'object'
            }
          }
        }
        Set_variable_domains_and_urls: {
          runAfter: {
            Compose_combine_urls_and_domain_array: [
              'Succeeded'
            ]
          }
          type: 'SetVariable'
          inputs: {
            name: 'domains_and_urls'
            value: '@outputs(\'Compose_combine_urls_and_domain_array\')'
          }
        }
        Initialize_variable_last_VT_analysis_results: {
          runAfter: {
            Initialize_variable_malicious_results: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'last_analysis_results'
                type: 'string'
              }
            ]
          }
        }
        Initialize_variable_email_body: {
          runAfter: {
            Initialize_variable_last_VT_analysis_results: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'email_body'
                type: 'string'
                value: '@body(\'Parse_JSON_from_functionapp\')?[\'email_content\']?[\'body\']'
              }
            ]
          }
        }
        Initialize_variable_attachments: {
          runAfter: {
            Initialize_variable_email_body: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'attachments'
                type: 'array'
                value: [
                  '@body(\'Parse_JSON_from_functionapp\')?[\'email_content\']?[\'attachments\']'
                ]
              }
            ]
          }
        }
        'Copilot_for_Security_-_Analyze_Email_Intent': {
          runAfter: {
            Check_if_domains_and_urls: [
              'Succeeded'
              'Failed'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'securitycopilot-1\'][\'connectionId\']'
              }
            }
            method: 'post'
            body: {
              PromptContent: '/AskGpt Objective: Analyze the body of this email for malicious intent and legitimacy "@{variables(\'email_body\')}" Indicators to Look For (analyze the available data points): 1. Sense of Urgency: Phrases like \'Act Now,\' \'Urgent Action Required,\' or \'Immediate Response Needed.\' 2. Generic Greetings: Greetings such as \'Dear Customer,\' \'Dear User,\' or \'Hello Friend.\' 3. Spelling or Grammar Mistakes: Frequent misspellings, improper grammar, or awkward phrasing. 4. Requests for Personal Information: Asking for sensitive details like passwords, Social Security numbers, or banking information. 5. Too Good to Be True Offers: Promises of large sums of money, prizes, or gifts. 6. Emotional Manipulation: Attempts to create fear, anxiety, or excitement to provoke a response. 7. Monetary Incentives: Offers of money, gift cards, or rewards for taking action. 8. Surveys and Gift Cards: Surveys promising rewards or gift cards for participation. 9. Unusual Requests: Requests that seem out of context or abnormal for the sender. 10. Suspicious Links or Phone Numbers: Urging the user to click on a link or call a phone number, especially when combined with other indicators. 11. Random Words: Presence of random words that do not make sense, used to bypass email filters. 12. Attachments or Links: Check if the sender is trying to get the recipient to open an attachment or click on a link, especially if combined with other suspicious indicators. Evaluate the body of the email based on these criteria to determine its legitimacy and potential malicious intent.'
            }
            path: '/process-prompt'
          }
        }
        'ParseEmailVT-parse_email': {
          runAfter: {
            For_each_attachment: [
              'Succeeded'
            ]
          }
          type: 'Function'
          inputs: {
            body: '@variables(\'raw_email\')'
            function: {
              id: '${resourceId('Microsoft.Web/sites', functionAppName)}/functions/parse_email'
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          'office365-1': {
            id: office365ApiConnection.id
            connectionId: office365ApiConnection.id
            connectionName: office365ConnectionName
          }
          'securitycopilot-1': {
            id: securityCopilotApiConnection.id
            connectionId: securityCopilotApiConnection.id
            connectionName: securityCopilotConnectionName
          }
        }
      }
    }
  }
}