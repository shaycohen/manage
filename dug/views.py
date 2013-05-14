from django.shortcuts import render
from django.http import HttpResponse
from django.views.generic.edit import CreateView, UpdateView, DeleteView
from django.core.urlresolvers import reverse_lazy
import jsonpickle
#import json

from dug.models import Job
from dug.forms import ListClientJobs

class JobCreate(CreateView):
    model = Job
    fields = ['desc','status']

class JobUpdate(UpdateView):
    model = Job
    fields = ['desc','status']

class JobDelete(DeleteView):
    model = Job
    success_url = reverse_lazy('jobs')

def jobs(request, client):
    var=Job.objects.get(client=client)
#json   pvar=json.dumps(json.loads(jsonpickle.encode(var)), indent=4) 
    return HttpResponse(jsonpickle.encode(var))

def listClientJobs(request):
    if request.method == 'POST': 
       form = ListClientJobs(request.POST)
       if form.is_valid(): 
          return render(request, 'listclientjobs.html', {'form': form, 'client': form.data.get('client')})
    else: 
       form = ListClientJobs()
       return render(request, 'listclientjobs.html', {'form': form})
