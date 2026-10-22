// Enable only the documented cross-service role for the Firebase Storage service agent.
const {api,project}=require('./cloud-access.cjs');
(async()=>{
 const info=await api(`https://cloudresourcemanager.googleapis.com/v1/projects/${project}`);
 const member=`serviceAccount:service-${info.projectNumber}@gcp-sa-firebasestorage.iam.gserviceaccount.com`;
 const url=`https://cloudresourcemanager.googleapis.com/v1/projects/${project}`;
 const policy=await api(`${url}:getIamPolicy`,'POST',{});
 policy.bindings ||= [];
 const role='roles/firebaserules.firestoreServiceAgent';
 let binding=policy.bindings.find(b=>b.role===role&&!b.condition);
 if(!binding){binding={role,members:[]};policy.bindings.push(binding);}
 if(!binding.members.includes(member)){
  binding.members.push(member);
  await api(`${url}:setIamPolicy`,'POST',{policy});
 }
 console.log('Firebase Storage service agent has cross-service Firestore rules access. Existing IAM bindings preserved.');
})().catch(e=>{console.error(e.message);process.exitCode=1});
