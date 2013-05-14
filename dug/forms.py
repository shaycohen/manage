from django import forms

class ListClientJobs(forms.Form):
	client = forms.CharField()
	job = forms.CharField()

