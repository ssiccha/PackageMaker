#
# PackageMaker - a GAP script for creating GAP packages
#
# Copyright (c) 2013-2014 Max Horn
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

if fail = LoadPackage("AutoDoc", ">= 2014.03.27") then
    Error("AutoDoc version 2014.03.27 is required.");
fi;

TranslateTemplate := function (template, outfile, subst)
    local out_stream, in_stream, line, pos, end_pos, key, val, i, tmp, c;
    
    if template = fail then
        template := Concatenation( "templates/", outfile, ".in" );
    fi;
    outfile := Concatenation( subst.PACKAGENAME, "/", outfile );

    in_stream := InputTextFile( template );
    out_stream := OutputTextFile( outfile, false );
    SetPrintFormattingStatus( out_stream, false );
    
    while not IsEndOfStream( in_stream ) do
        line := ReadLine( in_stream );
        if line = fail then
            break;
        fi;
        
        # Substitute {{ }} blocks
        pos := 0;
        while true do
            pos := PositionSublist( line, "{{", pos + 1 );
            if pos = fail then
                break;
            fi;
            
            end_pos := PositionSublist( line, "}}", pos + 1 );
            if end_pos = fail then
                continue;
            fi;
            
            key := line{[pos+2..end_pos-1]};
            if not IsBound(subst.(key)) then
                Error("Unknown substitution key '",key,"'\n");
            else
                val := subst.(key);
                if IsList(val) and IsRecord(val[1]) then
                    WriteAll( out_stream, line{[1..pos-1]} );
                    PrintTo( out_stream, "[\n" );
                    for i in [1..Length(val)] do
                        PrintTo( out_stream, "  rec(\n" );
                        for key in RecNames(val[i]) do
                            PrintTo( out_stream, "    ", key, " := ");
                            tmp := val[i].(key);
                            if IsString(tmp) then
                                if '\n' in tmp then
                                    PrintTo( out_stream, "Concatenation(\n" );
                                    tmp := SplitString(tmp,"\n");
                                    for c in [1..Length(tmp)-1] do
                                        PrintTo( out_stream, "               \"",tmp[c],"\\n\",\n");
                                    od;
                                    PrintTo( out_stream, "               \"",tmp[Length(tmp)],"\" )");
                                else
                                    PrintTo( out_stream, "\"" );
                                    for c in tmp do
                                        if c = '\n' then
                                            WriteByte( out_stream, IntChar('\\') );
                                            WriteByte( out_stream, IntChar('n') );
                                        else
                                            WriteByte( out_stream, IntChar(c) );
                                        fi;
                                    od;
                                    PrintTo( out_stream, "\"");
                                fi;
                            else
                                PrintTo( out_stream, tmp );
                            fi;
                            PrintTo( out_stream, ",\n" );
                        od;
                        PrintTo( out_stream, "  ),\n" );
                    od;
                    PrintTo( out_stream, "]" );
                    WriteAll( out_stream, line{[end_pos+2..Length(line)]} );
                    line := "";
                else
                    line := Concatenation( line{[1..pos-1]}, val, line{[end_pos+2..Length(line)]} );
                fi;
            fi;
            
#            Print("Found at pos ", [pos,from], " string '", line{[pos..end_pos+1]}, "'\n");
#            Print("Found at pos ", [pos,from], " string '", line{[pos+2..end_pos-1]}, "'\n");
        
        od;
        
        WriteAll( out_stream, line );
    
    od;
    
    
    CloseStream(out_stream);
    CloseStream(in_stream);
end;

# Return current date as a string with format DD/MM/YYYY.
# FIXME: This code has year 10,000 bug!
Today := function()
    local date;
    date := DMYDay(Int(Int(CurrentDateTimeString(["-u", "+%s"])) / 86400));
    date := date + [100, 100, 0];
    date := List( date, String );
    date := Concatenation( date[1]{[2,3]}, "/", date[2]{[2,3]}, "/", date[3] );
    return date;
end;

CreatePackage := function( pkgname )
    local authors, version, date, subst;

    authors := ValueOption( "authors" );
    if authors = fail then
        if IsBound( DefaultAuthor ) then
            authors := [ DefaultAuthor ];
        else
            Error("Missing author information");
        fi;
    fi;

# TODO:
# - add GitHub username / repository options,
#   and use those to set WWW and archive URLs
# -

    version := ValueOption( "version" );
    if version = fail then
        version := "0.1";
    fi;
    
    date := ValueOption( "date" );
    if date = fail then
        date := Today();
    fi;
    
    # TODO: we should prevent overwriting existing data.
    # But during testing, it is useful to be able to re-generate things quickly

    if not AUTODOC_CreateDirIfMissing( pkgname ) then
        Error("Failed to create package directory");
    fi;

    if not AUTODOC_CreateDirIfMissing( Concatenation( pkgname, "/gap" ) ) then
        Error("Failed to create `gap' directory in package directory");
    fi;

    subst := rec(
        PACKAGENAME := pkgname,
        DATE := date,
        VERSION := version,
        SUBTITLE := "TODO",
#        AUTHORS := "[ rec( TODO := true ) ]",
        AUTHORS := authors,
    );

    # TODO: For the source files, use ReadPackage() instead or so?
    TranslateTemplate(fail, "PackageInfo.g", subst );
    TranslateTemplate(fail, "init.g", subst );
    TranslateTemplate(fail, "read.g", subst );
    TranslateTemplate(fail, "makedoc.g", subst );
    TranslateTemplate("templates/gap/PKG.gi", Concatenation("gap/", pkgname, ".gi"), subst );
    TranslateTemplate("templates/gap/PKG.gd", Concatenation("gap/", pkgname, ".gd"), subst );


    if ValueOption( "kernel" ) = true then
        if not AUTODOC_CreateDirIfMissing( Concatenation( pkgname, "/src" ) ) then
            Error("Failed to create `src' directory in package directory");
        fi;
        # TODO: create a simple kernel extension and a build system???
    fi;


end;


FlushOutput := function()
    # FIXME: Is there a better alternative to this?
    Print("\c");
end;

AskYesNoQuestion := function( question )
    local stream, default, ans;

    stream := InputTextUser();

    Print(question);
    default := ValueOption( "default" );
    if default = true then
        Print(" [Y/n] "); FlushOutput();
    elif default = false then
        Print(" [y/N] "); FlushOutput();
    else
        default := fail;
        Print(" [y/n] "); FlushOutput();
    fi;

    while true do
        ans := CharInt(ReadByte(stream));
        if ans in "yYnN" then
            Print([ans,'\n']);
            ans := ans in "yY";
            break;
        elif ans = '\r' and default <> fail then
            Print("\n");
            ans := default;
            break;
        elif ans = '\c' then
            Print("\nUser aborted\n"); # HACK since Ctrl-C does not work
            JUMP_TO_CATCH("abort"); # HACK, undocumented command
        fi;
    od;

    CloseStream(stream);
    return ans;
end;

AskQuestion := function( question )
    local stream, default, ans;

    default := ValueOption( "default" );

    # Print the question prompt
    Print(question, " ");
    if default <> fail then
        Print("[", default, "] ");
    fi;
    FlushOutput();

    # Read user input
    stream := InputTextUser();
    ans := ReadLine(stream);    # FIXME: this disables Ctrl-C !!!!
    CloseStream(stream);

    # Clean it up
    if ans = "\n" and default <> fail then
        ans := default;
    else
        ans := Chomp(ans);
    fi;
    NormalizeWhitespace("ans");

    if ans = "quit" then Error("User aborted"); fi; # HACK since Ctrl-C does not work

    return ans;
end;

AskAlternativesQuestion := function( question, answers )
    local stream, default, i, ans;

    Assert(0, IsList(answers) and Length(answers) >= 2);

    default := ValueOption( "default" );
    if default = fail then
        default := 1;
    else
        Assert(0, default in [1..Length(answers)]);
    fi;

    for i in [1..Length(answers)] do
        Print(" (",i,")   ", answers[i][1], "\n");
    od;

    while true do
        ans := AskQuestion(question : default := default);

        if Int(ans) in [1..Length(answers)] then
            ans := answers[Int(ans)][2];
            break;
        fi;

        question := "Invalid choice. Please try again";
    od;

    return ans;
end;

PackageWizard := function()
    local pkginfo, repotype, date, p, github, alphanum, kernel;
    # TODO: store certain answers as user prefs,
    # at least info about the user

    Print("Welcome to the GAP PackageMaker wizard 0.1\n\
I will now guide you step-by-step through the package \
creation process by asking you some questions.\n\n");

    #
    # Phase 1: Ask lots of questions.
    #

    pkginfo := rec();

    while true do
        pkginfo.PackageName := AskQuestion("What is the name of the package?" : isValid := IsValidIdentifier);
        if IsValidIdentifier(pkginfo.PackageName) then
            break;
        fi;
        Print("Sorry, the package name must be a valid identifier (non-empty, only letters and digits, not a number, not a keyword)\n");
    od;
    if IsExistingFile(pkginfo.PackageName) then
        Print("ERROR: A file or directory with this name already exists.\n");
        Print("Please move it away or choose another package name.");
        return fail;
    fi;

    repotype := AskAlternativesQuestion("Shall I create a Git or Mercurial repository for your new package?",
                    [
                      [ "Yes, Git", "git" ],
                      [ "Yes, Mercurial", "hg" ],
                      [ "No", fail ]
                    ] );

    pkginfo.Subtitle := AskQuestion("Enter a short (one sentence) description of your package: "
                : isValid := g -> Length(g) < 80);

    #
    # Package version: Just default to 0.1dev. We could ask the user for
    # a version, but they only need to change one spot for it, and when
    # creating a new package, this is not so important.
    #
    pkginfo.Version := "0.1dev";
    #pkginfo.Version := AskQuestion("What is the version of your package?" : default := "0.1" );

    #
    # Package release date: just pick the current date. Similarly to the
    # package version, we don't allow customizing this in the wizard.
    #
    pkginfo.Date := Today();
    #pkginfo.Date := AskQuestion("What is the release date of your package?" : default := Today() );

    #
    # Package authors and maintainers
    #
    pkginfo.Persons := [];
    Print("\n");
    Print("Next I will ask you about the package authors and maintainers.\n\n");
    repeat
        p := rec();
        p.LastName := AskQuestion("Last name?");
        p.FirstNames := AskQuestion("First name(s)?");

        p.IsAuthor := AskYesNoQuestion("Is this one of the package authors?" : default := true);
        p.IsMaintainer := AskYesNoQuestion("Is this a package maintainer?" : default := true);

        # TODO: for the rest, offer automatic suggestions based on existing
        # package info records. Offer all matching records, ordered by frequency,
        # and as last option offer a "custom" choice
#         p.Email := AskQuestion("Email?");
#         p.WWWHome := AskQuestion("WWWHome?");
#         p.Place := AskQuestion("Place?");
#         p.Institution := AskQuestion("Institution?");
#         p.PostalAddress := AskQuestion("PostalAddress?");

        Add(pkginfo.Persons, p);
    until false = AskYesNoQuestion("Add another person?" : default := false);

    if repotype = "git" and true = AskYesNoQuestion("Setup for use with GitHub?" : default := true) then
        alphanum := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        github := rec();
        github.username := AskQuestion("What is your GitHub username?"
                            : isValid := n -> Length(n) > 0 and n[1] <> '-' and
                                    ForAll(n, c -> c = '-' or c in alphanum));
        github.reponame := AskQuestion("What is the repository name?"
                            : default := pkginfo.PackageName,
                              isValid := n -> Length(n) > 0 and
                                    ForAll(n, c -> c in "-._" or c in alphanum));
        github.gh_pages := true;
        #github.gh_pages := AskYesNoQuestion("Do you want to use GitHubPagesForGAP?" : default := true)
    fi;

    if github.gh_pages then
        pkginfo.PackageWWWHome := Concatenation("http://",github.username,".github.io/",github.reponame);
        # TODO: we need to tweak ArchiveURL here somehow...
    else
        pkginfo.PackageWWWHome := AskQuestion("URL of package homapage?");

    fi;

    kernel := AskYesNoQuestion("Does your package need a GAP kernel extension?" : default := false);
    # TODO: ask for C vs. C++?

return pkginfo;

    #
    # Phase 2: Create the package directory structure
    #

    # TODO: where to place the new package? current dir? allow user to customize?
    # TODO: what if there is already a dir with the given name in the target
    #       directory? Just error out?

    #if Exists(dir


    #
    # Phase 3 (optional): Setup a git repository and gh-pages
    #

    # TODO
end;