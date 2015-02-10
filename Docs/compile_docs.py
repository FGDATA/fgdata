#!/usr/bin/python

import xml.etree.ElementTree as etree
import os
import shutil
import re
from subprocess import call

FG_ROOT="../"

def tex_escape(text):
    """
        :param text: a plain text message
        :return: the message escaped to appear correctly in LaTeX
    """
    conv = {
        '&': r'\&',
        '%': r'\%',
        '$': r'\$',
        '#': r'\#',
        '_': r'\_',
        '{': r'\{',
        '}': r'\}',
        '~': r'\textasciitilde{}',
        '^': r'\^{}',
        '\\': r'\textbackslash{}',
        '<': r'\textless',
        '>': r'\textgreater',
    }
    regex = re.compile('|'.join(re.escape(unicode(key)) for key in sorted(conv.keys(), key = lambda item: - len(item))))
    return regex.sub(lambda match: conv[match.group()], text)

def generate_airplane_latex(source):
    """
        Generates the LaTeX files and directory structure for the procedures
    """
    root = os.path.join("procedures", source['name'])
    checklists_path = os.path.join(root, "checklists")
    if(not os.path.isdir(root)):
        os.mkdir(root)
    if(not os.path.isdir(checklists_path)):
        os.mkdir(checklists_path)

    # Write some warning notes
    preamble = open(os.path.join(root, "preamble.tex"), "w")

    preamble.write("\\section{Preamble}")
    preamble.write("This procedure list should be considered incomplete and it is not intended for real world use. It is automatically generated documentation intended for FlightGear flight simulator.")

    documentation_tex = open(os.path.join(root, source['dir'] + "_documentation.tex"), "w")
    documentation_tex.write("\\documentclass{article}\n")
    documentation_tex.write("\\usepackage{hyperref}\n\usepackage{graphicx}\n"
            "\\usepackage{fancyhdr}\\pagestyle{fancy}\n\\lfoot{Intended for FlightGear}\\rfoot{Not for real world use!}")
    documentation_tex.write("\\title{"+source['name']+" documentation}\n")
    documentation_tex.write("\\author{FlightGear team}\n")
    documentation_tex.write("\\renewcommand{\\familydefault}{\\sfdefault}")
    documentation_tex.write("\\begin{document}\n")
    documentation_tex.write("\\maketitle\n")

    checklist_tex = open(os.path.join(root, source['dir'] + "_checklist.tex"), "w")
    checklist_tex.write("\\documentclass{article}\n")
    checklist_tex.write("\\usepackage{fancyhdr}\\pagestyle{fancy}\n\\lfoot{Intended for FlightGear}\\rfoot{Not for real world use!}")
    checklist_tex.write("\\begin{document}\n")

    # If there's a thumbnail available, copy it into the documentation and include it
    # just before the beginning of the document, just after the title.
    if(source['thumbnail']):
        shutil.copyfile(FG_ROOT + "Aircraft/" + source['dir'] + "/thumbnail.jpg", 
                os.path.join(root, "thumbnail.jpg"))
        documentation_tex.write("\\begin{figure}[h!]\\centering")
        documentation_tex.write("\\includegraphics[width=5cm,height=5cm,keepaspectratio]{thumbnail.jpg}")
        documentation_tex.write("\\end{figure}")
    documentation_tex.write("\\tableofcontents\n")
    documentation_tex.write("\\input{preamble.tex}\n")

    # If any additional documentation, copy it to the procedures directory and
    # add it to the procedures.tex file
    if source['extra_documentation']:
        extra_docs_dir = os.path.join(FG_ROOT + "Aircraft/" + source['dir'], "Docs")
        extra_docs_dest_dir = os.path.join("procedures/" + source['name'], "Docs")
        if os.path.isdir(extra_docs_dest_dir):
            shutil.rmtree(extra_docs_dest_dir)
        shutil.copytree(extra_docs_dir, extra_docs_dest_dir)
        documentation_tex.write("\\input{Docs/" + source['dir'] + "_documentation}\n")

    # If there are any checklist files parsed, write a title
    if(source['sources'] > 0):
        documentation_tex.write("\\input{checklists.tex}\n")
        checklists_tex = open(os.path.join(root, "checklists.tex"), "w")
        checklists_tex.write("\\section{Checklists}\n")

    # and the checklists themselves.
    for xmlfile in source['sources']:
        tree = etree.parse(xmlfile)
        chkl_root = tree.getroot()
        for checklist in chkl_root:
            if checklist.tag != "checklist":
                print "Unrecognised tag in", xmlfile
                continue
            title = checklist.find("title")
            if title is None:
                title = "Untitled"
            else:
                title = tex_escape(title.text)
            items = []
           
            for item in checklist.findall("item"):
                name = item.find("name")
                value = item.find("value")
                if name is None or value is None:
                    continue
                if name.text is None or value.text is None:
                    continue
                items.append({
                    'name': tex_escape(name.text),
                    'value': tex_escape(value.text)
                    })
            filename = title + ".tex"
            filename = filename.replace("/", "_")
            filename = filename.replace(" ", "_")
            checklists_tex.write("\\subsection{" + title + "}\n")
            checklist_tex.write("\\section*{" + title + "}\n")
            checklists_tex.write("\\input{checklists/"+filename+"}\n")
            checklist_tex.write("\\input{checklists/"+filename+"}\n")
            f = open(os.path.join(checklists_path,filename), "w")
            if len(items) > 0:
                f.write("\\begin{description}\n")
                for item in items:
                    f.write("\\item["+item['name']+"] \dotfill " + item['value']+"\n")
                f.write("\\end{description}\n")
            checklist_tex.write("\\clearpage\n")

    documentation_tex.write("\\end{document}\n")
    checklist_tex.write("\\end{document}\n")

def gather_aircraft_metadata(directory = FG_ROOT + "Aircraft"):
    aircrafts = []
    for aircraft_directory in os.listdir(directory):
        for rootfile in os.listdir(os.path.join(directory, aircraft_directory)):
            rootfile = os.path.join(os.path.join(directory, aircraft_directory), rootfile)
            if not (os.path.isfile(rootfile) and rootfile.endswith("-set.xml")):
                continue
            # Houston, we found a set.xml. Let's read it. This implies an aircraft
            tree = etree.parse(rootfile)
            name = aircraft_directory


            for descr in tree.iter('description'):
                name = descr.text
                break
            aircraft = {
                    'sources'  : [],
                    'name'     : name,
                    'dir'     : aircraft_directory,
                    'thumbnail': False,
                    'extra_documentation': False
                    }
            # Check if the aircraft provides additional documentation
            aircraft['extra_documentation'] = os.path.isdir(os.path.join(directory, 
                aircraft_directory 
                + "/Docs/")) & os.path.isfile(os.path.join(directory, aircraft_directory
                    + "/Docs/" 
                    + aircraft_directory 
                    + "_documentation.tex"))
            # Check if there is a thumbnail
            if os.path.isfile(os.path.join(directory, aircraft_directory + "/thumbnail.jpg")):
                aircraft['thumbnail'] = True

            for checklist in tree.iter('checklists'):
                aircraft['sources'].append(os.path.join(directory, aircraft_directory, checklist.attrib['include']))
            if 'include' in tree.getroot().attrib:
                try:
                    tree = etree.parse(os.path.join(directory, aircraft_directory) + "/" + tree.getroot().attrib['include'])
                    for checklist in tree.iter('checklists'):
                        if 'include' in checklist.attrib:
                            aircraft['sources'].append(os.path.join(directory, aircraft_directory, checklist.attrib['include']))
                except:
                    pass
                


            if(len(aircraft['sources']) > 0 or aircraft['extra_documentation']):
                aircrafts.append(aircraft)

        # Check if there are checklists that can be parsed
        # for root, dirs, files in os.walk(os.path.join(directory, aircraft_directory), topdown=False):
        #     for name in files:
        #         if(name.endswith("checklists.xml")):
        #             aircraft['sources'].append(os.path.join(root,name))

    return aircrafts


def compile_airplane_latex(source):
    """
    Compile the procedures using pdflatex
    """
    wd = os.getcwd()
    root = os.path.join("procedures", source['name'])
    os.chdir(root)
    with open(os.devnull, "w") as fnull:
        mainfile = source['dir'] + "_documentation.tex"
        call(["pdflatex", "-interaction", "nonstopmode", mainfile], stdout=fnull,stderr=fnull)
        call(["pdflatex", "-interaction", "nonstopmode", mainfile], stdout=fnull,stderr=fnull)
        mainfile = source['dir'] + "_checklist.tex"
        call(["pdflatex", "-interaction", "nonstopmode", mainfile], stdout=fnull,stderr=fnull)
        call(["pdflatex", "-interaction", "nonstopmode", mainfile], stdout=fnull,stderr=fnull)
    os.chdir(wd)


def generate_airplane_documentation():
    # First generate the index of what should be included in the 
    # documentation
    aircrafts = gather_aircraft_metadata("../Aircraft")
    if(len(aircrafts) == 0 ):
        print "No aircraft found; wrong directory?"
    if(not os.path.isdir("procedures")):
        os.mkdir("procedures")

    # Then generate the documentation per airplane
    for aircraft in aircrafts:
        generate_airplane_latex(aircraft)
        compile_airplane_latex(aircraft)

# The main procedure
generate_airplane_documentation()
