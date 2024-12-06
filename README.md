# Render Deploy Manager 

A utility service to allow control of deploys across multiple services using either a parallel or sequential strategegy. 

## Usage

* Deploy this service as a Render blueprint to your account
* Use the `config_template.json` to prepare config and add it as secret file to the deployed service
* Make a GET request to /deploy?deploy_key=<your `deploy_key` value>
* Wait.


### Parallel strategy

with `"strategy": "parallel"` then all of your services in the group will be triggered to deploy at the same time

```
# Example output:
Triggering deploys for Club Manager Production
Deploying 2 services in parallel
Triggered deploy dep-ct9eit56l47c73arkrg0 for service srv-cp2on5i1hbls73822ef0
Triggered deploy dep-ct9eitq3esus73drb83g for service srv-cp2oqi63e1ms73f3168g
All services in the group were deployed successfully! 🚀
```

### Sequential Strategy

with `"strategy": "sequential"` then your services will be deployed in the order they are defined and will wait for success before triggering the next

```
# Example output:
Triggering deploys for Club Manager Production
Deploying 2 services sequentially
Triggered deploy dep-ct9eht9opnds73e8fevg for service srv-cp2on5i1hbls73822ef0
--> Current deployment status: update_in_progress
--> Current deployment status: live
Deploy dep-ct9eht9opnds73e8fevg is live! ✅
Triggered deploy dep-ct9ei0hopnds73e8fhhg for service srv-cp2oqi63e1ms73f3168g
--> Current deployment status: pre_deploy_in_progress
--> Current deployment status: 
--> Current deployment status: 
--> Current deployment status: update_in_progress
--> Current deployment status: live
Deploy dep-ct9ei0hopnds73e8fhhg is live! ✅
All services in the group were deployed successfully! 🚀
```


```