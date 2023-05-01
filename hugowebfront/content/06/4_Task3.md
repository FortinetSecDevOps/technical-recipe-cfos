---
title: "Task 3 - Deploy constraintTemplate"
chapter: true
weight: 4
---

### Task 3 - Deploy constraintTemplate

A ***ConstraintTemplate*** is a custom resource definition (CRD) used by the Gatekeeper project in Kubernetes. Gatekeeper is an open-source project that extends the Open Policy Agent (OPA) to provide policy enforcement and validation for Kubernetes clusters.

We use this CRD to validate the ***networkpolicy*** from gatekeeper admission controller. The ConstraintTemplate include Targets section which use rego to validate the rule.

{{< notice info >}}In the example, the target will call **cFOS** REST API to create firewall policy if condition is met, otherwise, the network policy request will be sent to kubernetes for creation. 
{{< /notice >}}

> Use below script to create ContraintTemplate

```
cat << EOF | kubectl create -f -
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8segressnetworkpolicytocfosutmpolicy
spec:
  crd:
    spec:
      names:
        kind: K8sEgressNetworkPolicyToCfosUtmPolicy
      validation:
        openAPIV3Schema:
          properties:
            message:
              type: string
            podcidr:
              type: string
            cfosegressfirewallpolicy:
              type: string 
            outgoingport:
              type: string
            utmstatus:
              type: string
            ipsprofile:
              type: string
            avprofile:
              type: string
            sslsshprofile:
              type: string 
            action:
              type: string
            srcintf:
              type: string
            firewalladdressapiurl:
              type: string
            firewallpolicyapiurl:
              type: string
            policyid :
              type: string 
            extraservice:
              type: string 

  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8segressnetworkpolicytocfosutmpolicy
        import future.keywords.if
        import future.keywords.in
        import future.keywords.contains
        
        
        services := {
        "HTTP": ["TCP:80"],
        "HTTPS": ["TCP:443"],
        "DNS": ["UDP:53"]
        }

        get_service(cfosservice) := msg1 {
          protocol := input.review.object.spec.egress[_].ports[_].protocol 
          port := sprintf("%v",[input.review.object.spec.egress[_].ports[_].port])
          key := concat(":", [ protocol, port ])
          some service; services[service][_] == key
          test := { service }
          cfosservice in test
          msg1 := cfosservice
         }

        myservice[{
           "name" : get_service("HTTPS")
          }] {
               1==1
         }
        myservice[{
           "name" : get_service("HTTP")
          }] {
               1==1
         }
        myservice[{
           "name" : get_service("DNS")
          }] {
               1==1
         }

         myservice[{"name":msg1}] {
         input.parameters.extraservice=="PING"
         msg1:="PING"
         }



          violation[{
            "msg" : msg 
          }] {
                          

                          
                          #the NetworkPolicy must has label under metadata which match the constraint
                          input.review.object.metadata.labels.app==input.parameters.label
                          
                          
                          #GET INPUT from reguar NetworkPolicy for cfos firewall policy
                          namespace := input.review.object.metadata.namespace
                          label := input.review.object.spec.podSelector.matchLabels.app
                             t := concat("",[namespace,"app"])
                          src_addr_group := concat("",[t,label])
                          dstipblock :=  input.review.object.spec.egress[_].to[_].ipBlock.cidr
                          policyname := input.review.object.metadata.name
                          
                          #GET INPUT from constraint template
                          policyid := input.parameters.policyid 
                          ipsprofile := input.parameters.ipsprofile
                          avprofile := input.parameters.avprofile
                          sslsshprofile := input.parameters.sslsshprofile
                          action  := input.parameters.action
                          srcintf := input.parameters.srcintf   
                          utmstatus := input.parameters.utmstatus
                          outgoingport := input.parameters.outgoingport
                          
                          
                          #firewalladdressapiurl := input.parameters.firewalladdressapiurl
                          firewallpolicyapiurl := input.parameters.firewallpolicyapiurl
                          firewalladdrgrpapiurl := input.parameters.firewalladdressgrpapiurl
        
                            #Begin Update cfos AddrGrp
                            #AddrGrp has an member with name "none"
                                      
                                      headers := {
                                      "Content-Type": "application/json",
                                      }
                            
                                      addrgrpbody := {
                                        "data":  {"name": src_addr_group, "member": [{"name": "none"}]}
                                      }
                            
                            
                                      addrGroupResp := http.send({
                                        "method": "POST",
                                        "url":  firewalladdrgrpapiurl,
                                        "headers": headers,
                                        "body": addrgrpbody
                                      })
                                      
                            #End Update cfos AddrGrp

                                      
                            #Begin of Firewall Policy update
                                      
                                      firewallPolicybody := {
                                        "data": 
                                          {"policyid":policyid, 
                                                  "name": policyname, 
                                                  "srcintf": [{"name": srcintf}], 
                                                  "dstintf": [{"name": outgoingport}], 
                                                  "srcaddr": [{"name": src_addr_group}],
                                                    #"service": [{"name":"ALL"}],
                                                  "service": myservice,
                                                  "nat":"enable",
                                                  "utm-status":utmstatus,
                                                  "action": "accept",
                                                  "logtraffic": "all",
                                                  "ssl-ssh-profile": sslsshprofile,
                                                  "ips-sensor": ipsprofile,
                                                  "webfilter-profile": "default",
                                                  "av-profile": avprofile,
                                                  "dstaddr": [{"name": "all"}]
                                          }
                                      }
                                      
                                      firewallPolicyResp := http.send({
                                        "method": "POST",
                                         "url":firewallpolicyapiurl, 
                                       "headers": headers,
                                         "body": firewallPolicybody
                                       })
                                      
                            #End of Firewall Policy Update       
 
                      msg :=sprintf(  "\n{%v %v  %v} ", [
                                                            addrGroupResp.status_code,
                                                            firewallPolicyResp.status_code,
                                                            myservice
                                                    ]
                                   )
              } 

EOF
```

> output will be similar as below

```
constrainttemplate.templates.gatekeeper.sh/k8segressnetworkpolicytocfosutmpolicy created
```