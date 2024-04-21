%{

#include<iostream>
#include<cstdlib>
#include<cstring>
#include<cmath>
#include<bits/stdc++.h>
#include "SymbolTable.cpp"


using namespace std;

int yyparse(void);
int yylex(void);



FILE *fp;
FILE *errors=fopen("error.txt","w");
FILE *logs= fopen("logs.txt","w");
int line_count=1;
int error_count=0;
int labelCount = 0;
int tempCount = 0;
extern FILE *yyin;

SymbolTable* symbolTable = new SymbolTable(logs,10);
string tempType;
vector<string> tempParameterList;
vector<string> tempParameterTypeList;
vector<string> ASM_varlist;
vector< pair<string,string> > ASM_arrlist;
vector< pair<string,string> > tempDeclareList;
vector<SymbolInfo*> tempArgList;
string tempCode = "";
string tempFuncName;
bool isPrintln = false;

string printlnCode =
 "PRINT_FUNC PROC  \n\
 	PUSH AX \n\ 
    PUSH BX \n\ 
    PUSH CX \n\ 
    PUSH DX  \n\ 
    CMP AX,0 \n\ 
    JGE BEGIN \n\ 
    PUSH AX \n\ 
    MOV DL,'-' \n\ 
    MOV AH,2 \n\ 
    INT 21H \n\ 
    POP AX \n\ 
    NEG AX \n\ 
    \n\ 
    BEGIN: \n\ 
    XOR CX,CX \n\ 
    MOV BX,10 \n\ 
    \n\ 
    REPEAT: \n\ 
    XOR DX,DX \n\ 
    DIV BX \n\ 
    PUSH DX \n\ 
    INC CX \n\ 
    OR AX,AX \n\ 
    JNE REPEAT \n\ 
    MOV AH,2 \n\ 
    \n\ 
    PRINT_LOOP: \n\ 
    POP DX \n\ 
    ADD DL,30H \n\ 
    INT 21H \n\ 
    LOOP PRINT_LOOP \n\ 
    \n\    
    MOV AH,2\n\
    MOV DL,10\n\
    INT 21H\n\
    \n\
    MOV DL,13\n\
    INT 21H\n\
	\n\
    POP DX \n\ 
    POP CX \n\ 
    POP BX \n\ 
    POP AX \n\ 
    ret \n\ 
    PRINT_FUNC ENDP \n\ ";

string newLabel()
{
	char *label= new char[8];
	strcpy(label,"Label");
	char buffer[3];
	sprintf(buffer,"%d", labelCount);
	labelCount++;
	strcat(label,buffer);
	return string(label);
}

string newTemp()
{
	char *temp= new char[4];
	strcpy(temp,"T");
	char buffer[3];
	sprintf(buffer,"%d", tempCount);
	tempCount++;
	strcat(temp,buffer);
	return  temp ;
}



void yyerror(char *s)
{
	//write your code
	fprintf(errors,"Line no %d : %s",line_count,s);
}



string refactor(string str)
{
	int ii=0; string temp;
	for(int i=0;i<str.length();i++)
	{
		if(str[i]==',')
		{
			str[i] = ' ';
		}
		if(str[i]!='\t' && str[i] != '\n' && str[i] != '\0')
		{
			str[ii++] = str[i];
		}
		
		
	}
	str[ii] = '\0';
	return str;
}


bool compare_line(string lhs,string rhs)
{
	bool ans = true;
	string one = refactor(lhs);
	string two = refactor(rhs);

	vector <string> tokens1;
	vector <string> tokens2;

	// stringstream class check1
	stringstream check1(one);

	string intermediate1;

	// Tokenizing w.r.t. space ' '
	while(getline(check1, intermediate1, ' '))
	{
	
		tokens1.push_back(intermediate1);
	}

	
	stringstream check2(two);

	string intermediate2;

	// Tokenizing w.r.t. space ' '
	while(getline(check2, intermediate2, ' '))
	{
		tokens2.push_back(intermediate2);
	}

	if(tokens1.size()==3 && tokens2.size()==3)
	{
		//cout <<"*"<< tokens1[1] <<"*"<< tokens2[2] <<"*" << tokens1[2] <<"*" << tokens2[1] <<"*" << endl;
		if(tokens1[0]=="MOV" && tokens2[0]=="MOV"  )
		{
			for(int i=0;i<2;i++)
			{
				if(tokens1[1][i]==tokens2[2][i] && tokens2[1][i]==tokens1[2][i])
				{
					//ans = true;
				}
				else 
					ans = false;
			}
		}
		else ans = false;

	}
	else ans = false;

	
	return ans;


}


%} 


%token IF ELSE FOR WHILE DO BREAK STRING ID PRINTLN INT FLOAT CHAR DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE CONST_INT CONST_FLOAT CONST_CHAR ADDOP MULOP INCOP RELOP ASSIGNOP LOGICOP BITOP NOT DECOP LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON


%left RELOP LOGICOP BITOP 
%left ADDOP 
%left MULOP

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%union
{
        SymbolInfo* s;
}

%type <s> start


%%

start : program
	{

	ofstream fout;
	fout.open("code.asm");
	ofstream ffout;
	ffout.open("optimized_code.asm");

	string outputCODE = "";
	
	outputCODE += ".MODEL SMALL \n.STACK 100H \n.DATA \n";
	
	

	for( int i=0; i< ASM_varlist.size() ; i++)
	{
		outputCODE += ASM_varlist[i]+" DW ? \n";
	}

	for(int i=0;i< ASM_arrlist.size();i++){
		outputCODE += ASM_arrlist[i].first+" dw "+ASM_arrlist[i].second+" dup(?)\n";
	}
	

	outputCODE += ".CODE\n";

	outputCODE += $<s>1->getASMcode();

	if(isPrintln==true)
		outputCODE += printlnCode;

	outputCODE += "END MAIN\n";



	fout << outputCODE << endl;


	outputCODE = "";

	/////////////// optimization ////////////////
	vector<string> code_lines;
	std::ifstream input( "code.asm" );

	for( std::string line; getline( input, line ); )
	{
    	code_lines.push_back(line);
	}

	int total_lines = code_lines.size();

	bool isOpt[total_lines];

	for(int i=0;i<total_lines;i++)
	{
		isOpt[i] = true;
	}

	for(int i=0;i<total_lines-1;i++)
	{
		
		if(compare_line(code_lines[i],code_lines[i+1])==true)
		{	
			cout << i+1 << " optimization "<< endl;
			isOpt[i+1] = false;
		}
	}

	for(int i=0;i<total_lines;i++)
	{
		if(isOpt[i])
			outputCODE += code_lines[i]+"\n";
	}

	ffout << outputCODE;

}

	

	;


program : program unit 
	  { 
	  	$<s>$ = new SymbolInfo();
		fprintf(logs,"Line at %d : program->program unit\n\n",line_count);
		fprintf(logs,"%s %s\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str()); 
		$<s>$->setName($<s>1->getName()+$<s>2->getName()) ;
		$<s>$->setASMcode($<s>1->getASMcode()+$<s>2->getASMcode());
	  }
	| unit
	  {
		$<s>$=new SymbolInfo(); 
		fprintf(logs,"Line at %d : program->unit\n\n",line_count);
		fprintf(logs,"%s\n\n",$<s>1->getName().c_str());
		$<s>$->setName($<s>1->getName());
		$<s>$->setASMcode($<s>1->getASMcode());
		
	  }

	;
	
unit : var_declaration
	  {
		$<s>$=new SymbolInfo(); 
		fprintf(logs,"Line at %d : unit->var_declaration\n\n",line_count);
		fprintf(logs,"%s\n\n",$<s>1->getName().c_str()); 
		$<s>$->setName($<s>1->getName()+"\n");
		
	  }

     | func_declaration
	  {
	  	$<s>$=new SymbolInfo();
	  	fprintf(logs,"Line at %d : unit->func_declaration\n\n",line_count);
	 	fprintf(logs,"%s\n\n",$<s>1->getName().c_str()); 
		$<s>$->setName($<s>1->getName()+"\n");
		
	  }

     | func_definition
	 {
		$<s>$=new SymbolInfo(); 
		fprintf(logs,"Line at %d : unit->func_definition\n\n",line_count);
	 	fprintf(logs,"%s\n\n",$<s>1->getName().c_str());
		$<s>$->setName($<s>1->getName()+"\n");
		$<s>$->setASMcode($<s>1->getASMcode());
		}
     ;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON

		{
		$<s>$=new SymbolInfo();
		fprintf(logs,"Line at %d : func_declaration->type_specifier ID LPAREN parameter_list RPAREN SEMICOLON\n\n",line_count);
		fprintf(logs,"%s %s(%s);\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str(),$<s>4->getName().c_str());
	
		if(symbolTable->lookup_global($<s>2->getName())==true)
		{
			SymbolInfo* ss = symbolTable->getInstanceOf_global($<s>2->getName());
			if(ss->isFunction()){
			error_count++;
			fprintf(errors,"Error at Line No.%d:  Multiple defination of function \n\n",line_count);
			}

			if(ss->isDeclared())
			{
			error_count++;
			fprintf(errors,"Error at Line No.%d:  Function declared more than one \n\n",line_count);
			
			}
		}
		else
		{
			SymbolInfo* ss = symbolTable->InsertIntoFunction($<s>2->getName(),$<s>1->getName());
			ss->declared = true;

			for(int i=0;i<tempParameterTypeList.size();i++) {
				ss->ptypes.push_back(tempParameterTypeList[i]);
			}

			

		}
	
		$<s>$->setName($<s>1->getName()+" "+$<s>2->getName()+"("+$<s>4->getName()+");");
			
		}



		| type_specifier ID LPAREN RPAREN SEMICOLON
		{
		$<s>$=new SymbolInfo();
		fprintf(logs,"Line at %d : func_declaration->type_specifier ID LPAREN parameter_list RPAREN SEMICOLON\n\n",line_count);
		fprintf(logs,"%s %s();\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str(),$<s>4->getName().c_str());
		
			if(symbolTable->lookup_global($<s>2->getName())==true)
			{

				SymbolInfo* ss = symbolTable->getInstanceOf_global($<s>2->getName());
				if(ss->isFunction()){
				error_count++;
				fprintf(errors,"Error at Line No.%d:  Multiple declaration of function \n\n",line_count);
				}

				
			}
			else
			{
				SymbolInfo* ss = symbolTable->InsertIntoFunction($<s>2->getName(),$<s>1->getName());
				ss->declared = true;

			}


		$<s>$->setName($<s>1->getName()+" "+$<s>2->getName()+"();");
		}
		;




		 
func_definition : type_specifier ID LPAREN parameter_list RPAREN {tempFuncName = $<s>2->getName(); } compound_statement
		{
			$<s>$=new SymbolInfo(); 
			tempCode = "";
			fprintf(logs,"Line at %d : func_definition->type_specifier ID LPAREN parameter_list RPAREN compound_statement\n\n",line_count);
			fprintf(logs,"%s %s(%s) %s\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str(),$<s>4->getName().c_str(),$<s>7->getName().c_str());
		
		if(symbolTable->lookup_global($<s>2->getName())==true )
		{
			
			SymbolInfo* ss = symbolTable->getInstanceOf_global($<s>2->getName());

			if(ss->isDefined())
			{
				error_count++;
				fprintf(errors,"Error at Line No.%d:  Multiple defination of function \n\n",line_count);
				
			}
		

			if(ss->isDeclared()==true && (ss->ptypes.size() != tempParameterTypeList.size()) )
			{
				error_count++;
				fprintf(errors,"Error at Line No.%d:  Invalid number of parameters as declared \n\n",line_count);
				
			}


			for(int i=0;i<tempParameterTypeList.size();i++){
					if(tempParameterTypeList[i] != ss->ptypes[i]) {
								error_count++;
								fprintf(errors,"Error at Line No.%d: Parameter Type Mismatch (%s,%s) \n\n",line_count,tempParameterTypeList[i],ss->ptypes[i]);
								break;
					}
			}

			if($<s>1->getName() != ss->returnType) {
					error_count++;
					fprintf(errors,"Error at Line No.%d: Return Type Mismatch \n\n",line_count);
					
			}
			


		}
		else
		{

			SymbolInfo* ss = symbolTable->InsertIntoFunction($<s>2->getName(),$<s>1->getName());
			ss->defined = true;

			for(int i=0;i<tempParameterList.size();i++) {
				ss->parameters.push_back(tempParameterList[i]);
				ss->ptypes.push_back(tempParameterTypeList[i]);
			}

			
			
			
			
		}

		
		$<s>$->setName($<s>1->getName()+" "+$<s>2->getName()+"("+$<s>4->getName()+")"+$<s>7->getName());

			tempCode += $<s>2->getName()+" PROC\n" ;
			tempCode += "\tPUSH AX\n\tPUSH BX \n\tPUSH CX \n\tPUSH DX\n";

		for(int i=0;i<tempParameterList.size();i++)
		{
			tempCode += "\tPUSH "+tempParameterList[i]+symbolTable->getScopeId()+"\n";
			ASM_varlist.push_back(tempParameterList[i]+symbolTable->getScopeId());
		}

		tempCode += $<s>7->getASMcode();
		tempCode += "LReturn"+$<s>2->getName()+":\n";
		for(int i=tempParameterList.size()-1;i>=0;i--)
		{
			tempCode += "\tPOP "+tempParameterList[i]+symbolTable->getScopeId()+"\n";
		}

		tempCode +="\tPOP DX\n\tPOP CX\n\tPOP BX\n\tPOP AX\n\tret\n";
													
		$<s>$->setASMcode(tempCode+$<s>2->getName()+" ENDP\n");

	
		ASM_varlist.push_back("return_"+$<s>2->getName());
		tempParameterTypeList.clear();
		tempParameterList.clear();
	
		}
			
		| type_specifier ID LPAREN RPAREN {tempFuncName = $<s>2->getName(); } compound_statement {
 			$<s>$=new SymbolInfo(); 
 			tempCode = "";

			fprintf(logs,"Line at %d : func_definition->type_specifier ID LPAREN RPAREN compound_statement\n\n",line_count);
			fprintf(logs,"%s %s() %s\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str(),$<s>6->getName().c_str());
			

			if(symbolTable->lookup_global($<s>2->getName())==true )
			{
			
			SymbolInfo* ss = symbolTable->getInstanceOf_global($<s>2->getName());

			if(ss->isDefined())
			{
				error_count++;
				fprintf(errors,"Error at Line No.%d:  Multiple defination of function \n\n",line_count);
				
			}
		

			if(ss->isDeclared()==true && (ss->ptypes.size() != tempParameterTypeList.size()) )
			{
				error_count++;
				fprintf(errors,"Error at Line No.%d:  Invalid number of parameters as declared (%d != %d) \n\n",line_count,ss->ptypes.size(),tempParameterTypeList.size());
				
			}



			

			if($<s>1->getName() != ss->returnType) {
					error_count++;
					fprintf(errors,"Error at Line No.%d: Return Type Mismatch \n\n",line_count);
					
			}
			


		}
		else
		{
			SymbolInfo* ss = symbolTable->InsertIntoFunction($<s>2->getName(),$<s>1->getName());
			ss->defined = true;
			
		}

		$<s>$->setName($<s>1->getName()+" "+$<s>2->getName()+"()"+$<s>6->getName());

			tempCode += $<s>2->getName()+" PROC\n" ;

			if($<s>2->getName() != "main") { // for other functions
			tempCode += "\tPUSH AX\n\tPUSH BX \n\tPUSH CX \n\tPUSH DX\n";
			tempCode += $<s>6->getASMcode();

			tempCode += "LReturn"+$<s>2->getName()+":\n";
			tempCode += "\tPOP DX\n\tPOP CX\n\tPOP BX\n\tPOP AX\n\tret\n";
			$<s>$->setASMcode(tempCode + $<s>2->getName()+" ENDP\n");
			}
			else // for only main function
			{
				
				tempCode += $<s>6->getASMcode();
				tempCode += "LReturn"+$<s>2->getName()+":\n";
				tempCode += "\tMOV AH,4CH\n\tINT 21H\n";
				$<s>$->setASMcode(tempCode);
			}

			ASM_varlist.push_back("return_"+$<s>2->getName());
			tempParameterTypeList.clear();
			tempParameterList.clear();
		//	symbolTable->Exit_Scope();
 		}
 		;		


parameter_list  : parameter_list COMMA type_specifier ID
		{
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : parameter_list->parameter_list COMMA type_specifier ID\n\n",line_count);
			fprintf(logs,"%s,%s %s\n\n",$<s>1->getName().c_str(),$<s>3->getName().c_str(),$<s>4->getName().c_str());


			tempParameterList.push_back($<s>4->getName());
			tempParameterTypeList.push_back($<s>3->getName());
			$<s>4->setSymbolId($<s>4->getName()+symbolTable->getScopeId());

			$<s>$->setName($<s>1->getName()+","+$<s>3->getName()+" "+$<s>4->getName());			
												 
		}
		| parameter_list COMMA type_specifier
 		{
 			$<s>$=new SymbolInfo();
 			fprintf(logs,"Line at %d : parameter_list->parameter_list COMMA type_specifier\n\n",line_count);
			fprintf(logs,"%s,%s\n\n",$<s>1->getName().c_str(),$<s>3->getName().c_str());

			tempParameterList.push_back("");
			tempParameterTypeList.push_back($<s>3->getName());


			$<s>$->setName($<s>1->getName()+","+$<s>3->getName());
			
 		}
 		| type_specifier ID
		{
			$<s>$=new SymbolInfo(); 
			fprintf(logs,"Line at %d : parameter_list->type_specifier ID\n\n",line_count);
		 	fprintf(logs,"%s %s\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str());
			
			tempParameterList.push_back($<s>2->getName());
			tempParameterTypeList.push_back($<s>1->getName());

			//ASM_varlist.push_back($<s>2->getName()+symbolTable->getScopeId());

		 	$<s>$->setName($<s>1->getName()+" "+$<s>2->getName());
		 	$<s>2->setSymbolId($<s>2->getName()+symbolTable->getScopeId());
		}
		| type_specifier
 		{
 			$<s>$=new SymbolInfo();
 			fprintf(logs,"Line at %d : parameter_list->type_specifier\n\n",line_count);
			fprintf(logs,"%s \n\n",$<s>1->getName().c_str());

			
			tempParameterTypeList.push_back($<s>1->getName());

			$<s>$->setName($<s>1->getName()+" ");
			
 		}
 		;

 		
compound_statement : LCURL { symbolTable->Enter_Scope(); } statements RCURL
 		    {
 		    	
 		    	$<s>$=new SymbolInfo(); 
 		    	fprintf(logs,"Line at %d : compound_statement->LCURL statements RCURL\n\n",line_count);
				fprintf(logs,"{%s}\n\n",$<s>3->getName().c_str());
				

				symbolTable->print_all();
				

				$<s>$->setName("{\n"+$<s>3->getName()+"\n}");
				$<s>$->setASMcode($<s>3->getASMcode());

 		    }
 		    | LCURL { symbolTable->Enter_Scope(); } RCURL
 		    {
 		    	symbolTable->Enter_Scope();
 		    	$<s>$=new SymbolInfo(); 
 		    	fprintf(logs,"Line at %d : compound_statement->LCURL RCURL\n\n",line_count);
			 	fprintf(logs,"{}\n\n");
			 	
			 	symbolTable->print_all();
			 

			 	$<s>$->setName("{}");
			 	
 		    }
 		    ;
 		    
var_declaration : type_specifier declaration_list SEMICOLON
 		 {
 		 	$<s>$=new SymbolInfo(); 
 		 	fprintf(logs,"Line at %d : var_declaration->type_specifier declaration_list SEMICOLON\n\n",line_count);
			fprintf(logs,"%s %s;\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str());
			
			tempType = $<s>1->getName();

			if($<s>1->getName().compare("void ")==0)
			{
			error_count++;
			fprintf(errors,"Error at Line No.%d: Type specifier can not be void \n\n",line_count);
			}

			

			for(int i=0;i<tempDeclareList.size();i++)
			{
				if(symbolTable->lookup_current(tempDeclareList[i].second)==true)
				{
					fprintf(errors,"Error at Line No.%d:  Multiple Declaration of %s \n\n",line_count,tempDeclareList[i].second.c_str());
					error_count++;
					}
				else
				{

					symbolTable->InsertInto(tempDeclareList[i].second, $<s>1->getName()); 
					ASM_varlist.push_back(tempDeclareList[i].second+symbolTable->getScopeId());
					tempDeclareList.push_back(make_pair(tempDeclareList[i].first,tempDeclareList[i].second));

				}
			}

			//tempDeclareList.clear();

			$<s>$->setName($<s>1->getName()+" "+$<s>2->getName()+";");		
										
 		 }
 		 ;
 		 
type_specifier	: INT
 		{
 			$<s>$=new SymbolInfo(); 
 			fprintf(logs,"Line at %d : type_specifier	: INT\n\n",line_count);fprintf(logs,"int \n\n");
			$<s>$->setName("int ");

			
 		}
 		| FLOAT
 		{
 			$<s>$=new SymbolInfo(); 
 			fprintf(logs,"Line at %d : type_specifier	: FLOAT\n\n",line_count);fprintf(logs,"float \n\n");
		 	$<s>$->setName("float ");
		 	

 		}
 		| VOID
 		{
 			$<s>$=new SymbolInfo(); 
 			fprintf(logs,"Line at %d : type_specifier	: VOID\n\n",line_count);fprintf(logs,"void \n\n");
		 	$<s>$->setName("void ");
		 	
 		}
 		;
 		
declaration_list : declaration_list COMMA ID
 		{
 			$<s>$=new SymbolInfo(); 
 			fprintf(logs,"Line at %d : declaration_list->declaration_list COMMA ID\n\n",line_count);
			fprintf(logs,"%s,%s\n\n",$<s>1->getName().c_str(),$<s>3->getName().c_str());
			
			tempDeclareList.push_back(make_pair(tempType,$<s>3->getName().c_str()));

			$<s>$->setName($<s>1->getName()+","+$<s>3->getName());
			
 		}
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
 		{
			$<s>$=new SymbolInfo(); 
			fprintf(logs,"Line at %d : declaration_list->declaration_list COMMA ID LTHIRD CONST_INT RTHIRD\n\n",line_count);
		   	fprintf(logs,"%s,%s[%s]\n\n",$<s>1->getName().c_str(),$<s>3->getName().c_str(),$<s>5->getName().c_str());
			//tempDeclareList.push_back(make_pair(tempType,$<s>3->getName().c_str()));
			ASM_arrlist.push_back(make_pair($<s>3->getName()+symbolTable->getScopeId(),$<s>5->getName()));
			$<s>3->isArray = true;
			$<s>$->setName($<s>1->getName()+","+$<s>3->getName()+"["+$<s>5->getName()+"]");	
															
 		}
 		  
 		  | ID
 		{
 			$<s>$=new SymbolInfo(); 
 			fprintf(logs,"Line at %d : declaration_list->ID\n\n",line_count);
		   	fprintf(logs,"%s\n\n",$<s>1->getName().c_str());
		   	tempDeclareList.push_back(make_pair(tempType,$<s>1->getName().c_str()));

		   	$<s>$->setName($<s>1->getName());
		   	//ASM_varlist.push_back($<s>1->getName()+symbolTable->getScopeId()); 
		   
 		}		
 		| ID LTHIRD CONST_INT RTHIRD
 		{

 		  $<s>$=new SymbolInfo(); 
 		  fprintf(logs,"Line at %d : declaration_list->ID LTHIRD CONST_INT RTHIRD\n\n",line_count);
		  fprintf(logs,"%s[%s]\n\n",$<s>1->getName().c_str(),$<s>3->getName().c_str());
		  tempDeclareList.push_back(make_pair(tempType,$<s>1->getName().c_str()));

		  $<s>$->setName($<s>1->getName()+"["+$<s>3->getName()+"]");
		 // ASM_varlist.push_back($<s>1->getName()+symbolTable->getScopeId()); 
		  
 		}

 		| ID LTHIRD CONST_FLOAT RTHIRD
 		{
 			$<s>$=new SymbolInfo(); 
			//fprintf(logs,"Line at %d : declaration_list->declaration_list COMMA ID LTHIRD CONST_INT RTHIRD\n\n",line_count);
		   	//fprintf(logs,"%s,%s[%s]\n\n",$<s>1->getName().c_str(),$<s>3->getName().c_str(),$<s>5->getName().c_str());

			$<s>$->setName($<s>1->getName()+"["+$<s>3->getName()+"]");
 			fprintf(errors,"Error at Line No.%d: Array size can not be a float \n\n",line_count);
			error_count++;
 		} 

 		;
 		  
statements : statement
	   {
			$<s>$=new SymbolInfo(); fprintf(logs,"Line at %d : statements->statement\n\n",line_count);
			fprintf(logs,"%s\n\n",$<s>1->getName().c_str()); 
			$<s>$->setName($<s>1->getName());
			$<s>$->setASMcode($<s>1->getASMcode());
			//cout << $<s>s->getASMcode();
	   }
	   | statements statement
	   {
	   	$<s>$=new SymbolInfo(); 
	   	fprintf(logs,"Line at %d : statements->statements statement\n\n",line_count);
	   	fprintf(logs,"%s %s\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str()); 
		$<s>$->setName($<s>1->getName()+"\n"+$<s>2->getName());
		$<s>$->setASMcode($<s>1->getASMcode()+$<s>2->getASMcode());
		//cout << $<s>s->getASMcode();
	   }
	   ;
	   
statement : var_declaration
	  {
		$<s>$=new SymbolInfo();
		fprintf(logs,"Line at %d : statement -> var_declaration\n\n",line_count);
		fprintf(logs,"%s\n\n",$<s>1->getName().c_str());
		$<s>$->setName($<s>1->getName()); 
		// lagbe na karon agei declare korsi

		$<s>$->setASMcode($<s>1->getASMcode());

	  }
	  | expression_statement
	  {
		$<s>$=new SymbolInfo();
		fprintf(logs,"Line at %d : statement -> expression_statement\n\n",line_count);
	  	fprintf(logs,"%s\n\n",$<s>1->getName().c_str()); 
		$<s>$->setName($<s>1->getName()); 
		$<s>$->setASMcode($<s>1->getASMcode());
	  }
	  | compound_statement
	  {
	  	$<s>$=new SymbolInfo();
	  	fprintf(logs,"Line at %d : statement->compound_statement\n\n",line_count);
	  	fprintf(logs,"%s\n\n",$<s>1->getName().c_str()); 
		$<s>$->setName($<s>1->getName()); 
		$<s>$->setASMcode($<s>1->getASMcode());
	  }
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  {
	  	tempCode = "";
		$<s>$=new SymbolInfo();
		fprintf(logs,"Line at %d : statement ->FOR LPAREN expression_statement expression_statement expression RPAREN statement\n\n",line_count);
	  	fprintf(logs,"for(%s %s %s)\n%s \n\n",$<s>3->getName().c_str(),$<s>4->getName().c_str(),$<s>5->getName().c_str(),$<s>7->getName().c_str());
		string label1 = newLabel();
		string label2 = newLabel();																	
		tempCode += $<s>3->getASMcode();
		tempCode += label1 + ":\n";
		tempCode += $<s>4->getASMcode();
		tempCode += "\tMOV AX," + $<s>4->getSymbolId()+"\n";
		tempCode += "\tCMP AX,0\n";
		tempCode += "\tJE "+label1+"\n";
		tempCode += $<s>7->getASMcode();
		tempCode += $<s>5->getASMcode();
		tempCode += "\tJMP "+label1+"\n";
		tempCode += label2 +":\n";
		$<s>$->setASMcode(tempCode);


		$<s>$->setName("for("+$<s>3->getName()+$<s>4->getName()+$<s>5->getName()+")\n"+$<s>5->getName()); 
		
	  }

	  
	  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	  {
	  	$<s>$=new SymbolInfo();
	  	fprintf(logs,"Line at %d : statement->IF LPAREN expression RPAREN statement\n\n",line_count);
	  	fprintf(logs,"if(%s)\n%s\n\n",$<s>3->getName().c_str(),$<s>5->getName().c_str());
		
	  	tempCode += $<s>3->getASMcode();
		string label1 = newLabel();
		tempCode += "\tMOV AX,"+$<s>3->getSymbolId()+"\n";
		tempCode += "\tCMP AX,0\n";
		tempCode += "\tJE " + label1 +"\n";
		tempCode += $<s>5->getASMcode();
		tempCode += label1+":\n";
		$<s>$->setASMcode(tempCode);

	  	$<s>$->setName("if("+$<s>3->getName()+")\n"+$<s>5->getName());
	  	
	  	$<s>$->setName("if("+$<s>3->getName()+")\n"+$<s>5->getName()); 
	  	
		}
	  | IF LPAREN expression RPAREN statement ELSE statement
	  {
	  	tempCode = "";
	  	$<s>$=new SymbolInfo();
	  	fprintf(logs,"Line at %d : statement->IF LPAREN expression RPAREN statement ELSE statement\n\n",line_count);
	  	fprintf(logs,"if(%s)\n%s\n else \n %s\n\n",$<s>3->getName().c_str(),$<s>5->getName().c_str(),$<s>7->getName().c_str());
		
		tempCode += $<s>3->getASMcode();
		string label1 = newLabel();
		string label2 = newLabel();
		tempCode += "\tMOV AX,"+$<s>3->getSymbolId()+"\n";
		tempCode += "\tCMP AX,0\n";
		tempCode += "\tJE "+ label1 +"\n";
		tempCode += $<s>5->getASMcode();
		tempCode += "\tJMP "+ label2 +"\n";
		tempCode += label1+":\n";
		tempCode += $<s>7->getASMcode();
		tempCode += label2+":\n";
		$<s>$->setASMcode(tempCode);

		$<s>$->setName("if("+$<s>3->getName()+")\n"+$<s>5->getName()+" else \n"+$<s>7->getName());
		
														
	  }
	  | WHILE LPAREN expression RPAREN statement
	  {
	  	$<s>$=new SymbolInfo();
	  	tempCode = "";
	  	fprintf(logs,"Line at %d : statement->WHILE LPAREN expression RPAREN statement\n\n",line_count);
	  	fprintf(logs,"while(%s)\n%s\n\n",$<s>3->getName().c_str(),$<s>5->getName().c_str());
												  
		string label1 = newLabel();
		string label2 = newLabel();
		tempCode += label1 +":\n";
		tempCode += $<s>3->getASMcode();
		tempCode += "\tMOV AX,"+$<s>3->getSymbolId()+"\n";
		tempCode += "\tCMP AX,0\n";
		tempCode += "\tJE "+ label2 +"\n";
		tempCode += $<s>5->getASMcode();
		tempCode += "\tJMP "+ label1 +"\n";
		tempCode += label2 +":\n";
		$<s>$->setASMcode(tempCode);

	  	$<s>$->setName("while("+$<s>3->getName()+")\n"+$<s>5->getName());
	  
	  }
	  | PRINTLN LPAREN ID RPAREN SEMICOLON
	  {
	  	$<s>$=new SymbolInfo();
	  	tempCode = "";
	  	fprintf(logs,"Line at %d : statement->PRINTLN LPAREN ID RPAREN SEMICOLON\n\n",line_count);
	  	fprintf(logs,"\n println(%s);\n\n",$<s>3->getName().c_str());
	  	SymbolInfo* ss = symbolTable->getInstanceOf_current($<s>1->getName());
		if(ss != 0){
			error_count++;
			fprintf(errors,"Error at Line No.%d:  Undeclared Variable: %s \n\n",line_count,$<s>3->getName().c_str());
		}
		
		tempCode += "\tMOV AX,"+$<s>3->getName()+symbolTable->getScopeId();
		tempCode += "\n\tCALL PRINT_FUNC\n";

		isPrintln = true;
		$<s>$->setASMcode(tempCode); 
		$<s>$->setName("\nprintln("+$<s>3->getName()+")"); 
	
	  }
	  | RETURN expression SEMICOLON
	  {
	  	tempCode = "";
	  	$<s>$=new SymbolInfo();
	  	fprintf(logs,"Line at %d : statement->RETURN expression SEMICOLON\n\n",line_count);
	  	fprintf(logs,"return %s;\n\n",$<s>2->getName().c_str());

	  	tempCode += $<s>2->getASMcode();
		tempCode += "\tMOV AX,"+$<s>2->getSymbolId()+"\n";
		tempCode += "\tMOV return_" +tempFuncName	+",AX\n";
		tempCode += "\tJMP LReturn"+ tempFuncName+"\n";
		$<s>$->setASMcode(tempCode);
	  	$<s>$->setName("return "+$<s>2->getName()+";"); 
	  	
	  }
	  ;
	  
expression_statement 	: SEMICOLON			
		{
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : expression_statement->SEMICOLON\n\n",line_count);
			fprintf(logs,";\n\n"); 
			$<s>$->setName(";");
			
		}
			| expression SEMICOLON 
		{
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : statement->RETURN expression SEMICOLON\n\n",line_count);
	  		fprintf(logs,"return %s;\n\n",$<s>2->getName().c_str());


	  		$<s>$->setName($<s>1->getName()+";"); 
	  		$<s>$->setASMcode($<s>1->getASMcode());
			$<s>$->setSymbolId($<s>1->getSymbolId());
		}
		;
		
	  
variable : ID 		
	 	{
	 		$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : variable->ID\n\n",line_count);
			fprintf(logs,"%s\n\n",$<s>1->getName().c_str());

			SymbolInfo* ss = symbolTable->getInstanceOf_current($<s>1->getName());
			if(ss != 0)
				$<s>$->returnType = ss->returnType;

			$<s>$->setName($<s>1->getName());
			$<s>$->isArray = false;
			$<s>1->setSymbolId($<s>1->getName()+symbolTable->getScopeId());
			$<s>$->setSymbolId($<s>1->getName()+symbolTable->getScopeId());
			
	 	}
	 | ID LTHIRD expression RTHIRD 
	 	{
	 		$<s>$=new SymbolInfo();
	 		fprintf(logs,"Line at %d : variable->ID LTHIRD expression RTHIRD\n\n",line_count);
	 		fprintf(logs,"%s[%s]\n\n",$<s>1->getName().c_str(),$<s>3->getName().c_str());
	 		
	 		if($<s>3->returnType=="float ")
	 		{
	 			error_count++;
	 			fprintf(errors,"Error at Line No.%d:  Array index can not be an floating number \n\n",line_count);
				
	 		}
	 		$<s>$->isArray = true;
	 		SymbolInfo* ss = symbolTable->getInstanceOf_global($<s>1->getName());
			if(ss != 0)
				$<s>$->returnType = ss->returnType;
	 		$<s>$->setName($<s>1->getName()+"["+$<s>3->getName()+"]");  
	 		$<s>$->setSymbolId($<s>1->getName()+symbolTable->getScopeId());
	 		$<s>1->setSymbolId($<s>1->getName()+symbolTable->getScopeId());
	 	}

	 ;
	 
expression : logic_expression	
	   {
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : expression->logic_expression\n\n",line_count);
 			fprintf(logs,"%s\n\n",$<s>1->getName().c_str());

 			$<s>$->returnType = $<s>1->returnType;
 			$<s>$->setName($<s>1->getName()); 
 			$<s>$->setASMcode($<s>1->getASMcode());
			$<s>$->setSymbolId($<s>1->getSymbolId());
	   }
	   | variable ASSIGNOP logic_expression 	
	   {
	   		tempCode = "";
	   		$<s>$=new SymbolInfo();
	   		fprintf(logs,"Line at %d : expression->variable ASSIGNOP logic_expression\n\n",line_count);
	   		fprintf(logs,"%s=%s\n\n",$<s>1->getName().c_str(),$<s>3->getName().c_str());
	   			
	   			SymbolInfo* ss = symbolTable->getInstanceOf_current($<s>1->getName());
	   		
	   			if(ss == 0)
	   			{
	   				fprintf(errors,"Error at Line No.%d: Undeclared Variable: %s \n\n",line_count,$<s>1->getName().c_str());
		   			error_count++;
 
	   			}

		   		else if($<s>3->returnType != $<s>1->returnType)
		   		{
		   		error_count++;
		   		fprintf(errors,"Error at Line No.%d: Type Mismatch [ type : %s != type: %s ] \n\n",line_count,$<s>1->returnType.c_str(),$<s>3->returnType.c_str());
		   		} 
		   		else
		   		{
		   			//fprintf(errors,"Line No.%d: Type matched ( %s == %s ) \n\n",line_count,$<s>1->returnType.c_str(),$<s>3->returnType.c_str());
		   		
		   		}

		   		tempCode += $<s>1->getASMcode();
				tempCode += $<s>3->getASMcode();
				tempCode += "\tMOV AX," + $<s>3->getSymbolId()+"\n";

				if($<s>1->isArray==false)
					tempCode += "\tMOV " + $<s>1->getSymbolId()+",AX\n";
				else
					tempCode += "\tMOV "+$<s>1->getSymbolId()+"[BX],AX\n";
				
				$<s>$->setASMcode(tempCode);

				$<s>$->setSymbolId($<s>1->getSymbolId());
	   		
	   		

	   		$<s>$->setName($<s>1->getName()+"="+$<s>3->getName());  
	   }
	   ;
			
logic_expression : rel_expression 	
		{
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : logic_expression->rel_expression\n\n",line_count);
			fprintf(logs,"%s\n\n",$<s>1->getName().c_str());

			$<s>$->setASMcode($<s>1->getASMcode());
			$<s>$->setSymbolId($<s>1->getSymbolId());
			$<s>$->returnType = $<s>1->returnType;
			$<s>$->setName($<s>1->getName()); 
		}
		 | rel_expression LOGICOP rel_expression 	
		{
			tempCode = "";
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : logic_expression->rel_expression LOGICOP rel_expression\n\n",line_count);
		 	fprintf(logs,"%s%s%s\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str(),$<s>3->getName().c_str());
			$<s>$->returnType = "int ";

			tempCode += $<s>1->getASMcode();
			tempCode += $<s>3->getASMcode();
			string label1 = newLabel();
			string label2 = newLabel();
			string label3 = newLabel();
			string temp = newTemp();

			if($<s>2->getName()=="||"){
				tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"\n";
				tempCode += "\tCMP AX,0\n";
				tempCode += "\tJNE "+ label2 +"\n";
				tempCode += "\tMOV AX,"+ $<s>3->getSymbolId()+"\n";
				tempCode += "\tCMP AX,0\n";
				tempCode += "\tJNE "+ label2 +"\n";
				tempCode += label1 +":\n";
				tempCode += "\tMOV "+ temp +",0\n";
				tempCode += "\tJMP "+ label3 +"\n";
				tempCode += label2 +":\n";
				tempCode += "\tMOV "+ temp +",1\n";
				tempCode += label3 +":\n";

			}
			else{
				tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"\n";
				tempCode += "\tCMP AX,0\n";
				tempCode += "\tJE "+ label2 +"\n";
				tempCode += "\tMOV AX,"+$<s>3->getSymbolId()+"\n";
				tempCode += "\tCMP AX,0\n";
				tempCode += "\tJE "+ label2 +"\n";
				tempCode += label1 + ":\n";
				tempCode += "\tMOV "+ temp +",1\n";
				tempCode += "\tJMP "+ label3 +"\n";
				tempCode += label2 + ":\n";
				tempCode += "\tMOV "+ temp +",0\n";
				tempCode += label3 + ":\n";

			}
			$<s>$->setASMcode(tempCode);
			$<s>$->setSymbolId(temp);
			ASM_varlist.push_back(temp);

	
		 	$<s>$->setName($<s>1->getName()+$<s>2->getName()+$<s>3->getName()); 
		}
		;
		
			
rel_expression	: simple_expression 
		{
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : rel_expression->simple_expression\n\n",line_count);
			fprintf(logs,"%s\n\n",$<s>1->getName().c_str());
			$<s>$->setASMcode($<s>1->getASMcode());
			$<s>$->setSymbolId($<s>1->getSymbolId());
			$<s>$->returnType = $<s>1->returnType;
			$<s>$->setName($<s>1->getName());
		}
		| simple_expression RELOP simple_expression	
		{
			tempCode = "";
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : rel_expression->simple_expression RELOP simple_expression\n\n",line_count);
			fprintf(logs,"%s%s%s\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str(),$<s>3->getName().c_str());
			$<s>$->returnType = "int ";

			tempCode += $<s>1->getASMcode();
			tempCode += $<s>3->getASMcode();
			string temp = newTemp();
			string label1 = newLabel();
			string label2 = newLabel();
			tempCode += "\tMOV AX," + $<s>1->getSymbolId()+"\n";
			tempCode += "\tCMP AX," + $<s>3->getSymbolId()+"\n";

			if($<s>2->getName()=="<"){
				tempCode += "\tJL "+ label1 +"\n";

			}
			else if($<s>2->getName()==">"){
				tempCode += "\tJG "+ label1 +"\n";

			}
			else if($<s>2->getName()=="<="){
				tempCode += "\tJLE "+ label1 +"\n";

			}
			else if($<s>2->getName()==">="){
				tempCode += "\tJGE "+ label1 +"\n";

			}
			else if($<s>2->getName()=="=="){
				tempCode += "\tJE "+ label1 +"\n";

			}
			else if($<s>2->getName()=="!="){
				tempCode += "\tJNE "+ label1 +"\n";

			}
			tempCode += "\tMOV "+ temp +",0\n";
			tempCode += "\tJMP "+ label2 +"\n";
			tempCode +=  label1 +":\n";
			tempCode += "\tMOV "+ temp +",1\n";
			tempCode +=  label2 +":\n";
			ASM_varlist.push_back(temp);
			$<s>$->setASMcode(tempCode);
			$<s>$->setSymbolId(temp);

			$<s>$->setName($<s>1->getName()+$<s>2->getName()+$<s>3->getName());											
		}
		;
				
simple_expression : term 
		{
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : simple_expression->term\n\n",line_count);
			fprintf(logs,"%s\n\n",$<s>1->getName().c_str());

			$<s>$->returnType = $<s>1->returnType;
			$<s>$->setName($<s>1->getName());
			$<s>$->setASMcode($<s>1->getASMcode());
			$<s>$->setSymbolId($<s>1->getSymbolId());
		}
		| simple_expression ADDOP term 
		{
			tempCode = "";
			$<s>$=new SymbolInfo(); 
		  	fprintf(logs,"Line at %d : simple_expression->simple_expression ADDOP term\n\n",line_count);
		  	fprintf(logs,"%s%s%s\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str(),$<s>3->getName().c_str());
			
		  	if($<s>1->returnType=="float " || $<s>3->returnType=="float ")
     			$<s>$->returnType = "float ";
     		else
     			$<s>$->returnType = "int ";

     		tempCode += $<s>1->getASMcode()+$<s>3->getASMcode();

			tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"\n";
			string temp=newTemp();

			if($<s>2->getName()=="+"){
				tempCode += "\tADD AX,"+$<s>3->getSymbolId()+"\n";
			}
			else{
				tempCode +="\tSUB AX,"+$<s>3->getSymbolId()+"\n";

			}
			tempCode += "\tMOV "+ temp +",AX\n";
			$<s>$->setASMcode(tempCode);
			$<s>$->setSymbolId(temp);
			ASM_varlist.push_back(temp);

			$<s>$->setName($<s>1->getName()+$<s>2->getName()+$<s>3->getName()); 
		}
		;
		
					
term :	unary_expression
     	{
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : term->unary_expression\n\n",line_count);
			fprintf(logs,"%s\n\n",$<s>1->getName().c_str());

			$<s>$->setASMcode($<s>1->getASMcode());
			$<s>$->setSymbolId($<s>1->getSymbolId());
			$<s>$->returnType = $<s>1->returnType;
			$<s>$->setName($<s>1->getName());
     	}
     |  term MULOP unary_expression
     	{
     		tempCode = "";
     		string temp = newTemp();
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : term->term MULOP unary_expression\n\n",line_count);
	 		fprintf(logs,"%s%s%s\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str(),$<s>3->getName().c_str());


     		if($<s>2->getName()=="%"){
				 if($<s>1->returnType!="int " || $<s>3->returnType!="int "){
					error_count++;
					fprintf(errors,"Error at Line No.%d:  Integer operand on modulus operator  \n\n",line_count);
				 }
				 else 
				 	$<s>$->returnType = "int ";

				 tempCode += $<s>1->getASMcode()+$<s>3->getASMcode();
				 tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"\n";
				 tempCode += "\tMOV BX,"+$<s>3->getSymbolId()+"\n";
				 tempCode += "\tMOV DX,0\n";
				 tempCode += "\tDIV BX\n";
				 tempCode += "\tMOV "+ temp +", DX\n";
				


			} 
			else if($<s>2->getName()=="/")
			{
					if($<s>1->returnType=="int " && $<s>3->returnType=="int ")
						$<s>$->returnType = "int "; 
					else 
						$<s>$->returnType = "float "; 

					 tempCode += $<s>1->getASMcode()+$<s>3->getASMcode();
					 tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"\n";
					 tempCode += "\tMOV BX,"+$<s>3->getSymbolId()+"\n";
					 tempCode += "\tDIV BX\n";
					 tempCode += "\tMOV "+ temp +", AX\n";
			}

			else if($<s>2->getName()=="*"){

					if($<s>1->returnType=="float " || $<s>3->returnType=="float ")
						$<s>$->returnType = "float "; 
					else 
						$<s>$->returnType = "int ";

				 tempCode += $<s>1->getASMcode()+$<s>3->getASMcode();
				 tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"\n";
				 tempCode += "\tMOV BX,"+$<s>3->getSymbolId()+"\n";
				 tempCode += "\tMUL BX\n";
				 tempCode += "\tMOV "+string(temp)+", AX\n";


			}

			 $<s>$->setASMcode(tempCode);
			 $<s>$->setSymbolId(temp);
			 ASM_varlist.push_back(temp);
	 		 $<s>$->setName($<s>1->getName()+$<s>2->getName()+$<s>3->getName());
     	}
     ;

unary_expression : ADDOP unary_expression  
		{
			tempCode = "";
			$<s>$=new SymbolInfo(); 
			fprintf(logs,"Line at %d : unary_expression->ADDOP unary_expression\n\n",line_count);
			fprintf(logs,"%s%s\n\n",$<s>1->getName().c_str(),$<s>2->getName().c_str());

			tempCode += $<s>2->getASMcode();
			if($<s>1->getName()=="-"){
				tempCode += "\tMOV AX,"+$<s>2->getSymbolId()+"\n";
				tempCode += "\tNEG AX\n";
				tempCode += "\tMOV "+$<s>2->getSymbolId()+",AX\n";
			}

			$<s>$->setASMcode(tempCode);
			$<s>$->setSymbolId($<s>2->getSymbolId());	
			$<s>$->returnType = $<s>2->returnType;
			$<s>$->setName($<s>1->getName()+$<s>2->getName());
											
		}
		 | NOT unary_expression 
		{
			tempCode = "";
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : unary_expression->NOT unary_expression\n\n",line_count);
			fprintf(logs,"!%s\n\n",$<s>2->getName().c_str());

			tempCode += $<s>2->getASMcode();
			tempCode += "\tMOV AX," + $<s>2->getSymbolId()+"\n";
			tempCode += "\tNOT AX\n";
			tempCode += "\tMOV " + $<s>2->getSymbolId()+",AX\n";

			$<s>$->setASMcode(tempCode);
			$<s>$->setSymbolId($<s>2->getSymbolId());
			$<s>$->returnType = "int ";
			$<s>$->setName("!"+$<s>2->getName()); 
		}
		 | factor 
		
		{
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : unary_expression->factor\n\n",line_count);
		 	fprintf(logs,"%s\n\n",$<s>1->getName().c_str());

		 	$<s>$->setASMcode($<s>1->getASMcode());
			$<s>$->setSymbolId($<s>1->getSymbolId());
		 	$<s>$->returnType = $<s>1->returnType;
		 	$<s>$->setName($<s>1->getName()); 
		}
		;
	
factor	: variable 
		{
			tempCode = "";
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : factor->variable\n\n",line_count);
			fprintf(logs,"%s\n\n",$<s>1->getName().c_str());

			SymbolInfo* ss = symbolTable->getInstanceOf_current($<s>1->getName());
			if(ss != 0){
				$<s>$->returnType = ss->returnType;

				tempCode += $<s>1->getASMcode();
				if(ss->isArray==true)
				{	
					string temp=newTemp();
					tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"[BX]\n";
					tempCode += "\tMOV "+ temp +",AX\n";
					ASM_varlist.push_back(temp);
					$<s>$->setSymbolId(temp);
				}
				else{
					$<s>$->setSymbolId($<s>1->getSymbolId());
				}
			}


			$<s>$->setASMcode(tempCode);
			$<s>$->setName($<s>1->getName());
		}
	| ID LPAREN argument_list RPAREN
		{
			tempCode = "";
			$<s>$=new SymbolInfo(); 
			fprintf(logs,"Line at %d : factor->ID LPAREN argument_list RPAREN\n\n",line_count);
			fprintf(logs,"%s(%s)\n\n",$<s>1->getName().c_str(),$<s>3->getName().c_str());

			SymbolInfo* ss = symbolTable->getInstanceOf_global($<s>1->getName());

			if(ss != 0) 
			 	$<s>$->returnType = ss->returnType;

			if(ss == 0 )
			{
				error_count++;
				fprintf(errors,"Error at Line No.%d:  Undefined Function \n\n",line_count);
			}
			else if(ss->isFunction()==false)
			{
				error_count++;
				fprintf(errors,"Error at Line No.%d:  Not a function \n\n",line_count);
			}
			else if(tempArgList.size() != ss->ptypes.size())
			{
				error_count++;
				fprintf(errors,"Error at Line No.%d:  Invalid number of arguments %d and %d \n\n",line_count,tempArgList.size(),ss->ptypes.size());

			}

			for(int i=0;i<tempArgList.size();i++){
				tempCode += "\tMOV AX,"+tempArgList[i]->getSymbolId()+"\n";
				//tempCode += "\tMOV "+para_list[i]+",AX\n";
			
			}
			
			tempCode += "\tCALL "+$<s>1->getName()+"\n";
		
			tempCode += "\tMOV AX, return_"+$<s>1->getName()+"\n";
			string temp = newTemp();
			tempCode += "\tMOV "+ temp+",AX\n";
			
			$<s>$->setASMcode(tempCode);
			$<s>$->setSymbolId(temp);
			$<s>1->setSymbolId(temp);
			ASM_varlist.push_back(temp);


			$<s>$->setName($<s>1->getName()+"("+$<s>3->getName()+")"); 
			tempArgList.clear();
		}
	| LPAREN expression RPAREN
		{
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : factor->LPAREN expression RPAREN\n\n",line_count);
			fprintf(logs,"(%s)\n\n",$<s>2->getName().c_str()); 

			$<s>$->setSymbolId($<s>2->getSymbolId());
			$<s>$->setASMcode($<s>2->getASMcode());
			$<s>$->returnType = $<s>2->returnType;
			$<s>$->setName("("+$<s>2->getName()+")");
		}
	| CONST_INT 
		{
			tempCode = "";
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : factor->CONST_INT\n\n",line_count);
			fprintf(logs,"%s\n\n",$<s>1->getName().c_str());
			string temp = newTemp();
			$<s>$->returnType = "int ";
			$<s>$->setName($<s>1->getName());
			tempCode += "\tMOV "+ temp +"," +$<s>1->getName()+"\n";
			$<s>$->setASMcode(tempCode);
			$<s>$->setSymbolId(temp); 
			ASM_varlist.push_back(temp);
		}
	| CONST_FLOAT
		{
			tempCode = "";
			$<s>$=new SymbolInfo();
			fprintf(logs,"Line at %d : factor->CONST_FLOAT\n\n",line_count);
			fprintf(logs,"%s\n\n",$<s>1->getName().c_str()); 
			
			string temp = newTemp();
			$<s>$->returnType = "float ";
			$<s>$->setName($<s>1->getName());
			tempCode += "\tMOV "+ temp +"," +$<s>1->getName()+"\n";
			$<s>$->setASMcode(tempCode);
			$<s>$->setSymbolId(temp); 
			ASM_varlist.push_back(temp);
		}
	| variable INCOP 
		{
			$<s>$=new SymbolInfo();
			string temp = newTemp();
			tempCode = "";
			fprintf(logs,"Line at %d : factor->variable INCOP\n\n",line_count);
			fprintf(logs,"%s++\n\n",$<s>1->getName().c_str()); 

			if($<s>1->isArray==true)
				tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"[BX]\n";
			else
				tempCode += "\tMOV AX," + $<s>1->getSymbolId()+"\n";
			
			tempCode += "\tMOV "+ temp +",AX\n";
					
			if($<s>1->isArray==true){
				tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"[BX]\n";
				tempCode += "\tINC AX\n";
				tempCode += "\tMOV "+$<s>1->getSymbolId()+"[BX],AX\n";
			}
			else
				tempCode += "\tINC "+$<s>1->getSymbolId()+"\n";
			
			ASM_varlist.push_back(temp);
			$<s>$->setASMcode(tempCode); 
			$<s>$->setSymbolId(temp);
			$<s>$->returnType = $<s>1->returnType;
			$<s>$->setName($<s>1->getName()+"++"); 
		}
	| variable DECOP
		{
			$<s>$=new SymbolInfo();
			string temp = newTemp();
			tempCode = "";
			fprintf(logs,"Line at %d : factor->variable DECOP\n\n",line_count);
			fprintf(logs,"%s--\n\n",$<s>1->getName().c_str());


			if($<s>1->isArray==true)
				tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"[BX]\n";
			else
				tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"\n";
					
			tempCode += "\tMOV "+ temp +",AX\n";
			
			if($<s>1->isArray==true){
				tempCode += "\tMOV AX,"+$<s>1->getSymbolId()+"[BX]\n";
				tempCode += "\tDEC AX\n";
				tempCode += "\tMOV "+$<s>1->getSymbolId()+"[BX],AX\n";
			}
			else
				tempCode += "\tDEC "+$<s>1->getSymbolId()+"\n";

			ASM_varlist.push_back(temp);
			$<s>$->setASMcode(tempCode); 
			$<s>$->setSymbolId(temp);


			$<s>$->returnType = $<s>1->returnType;
			$<s>$->setName($<s>1->getName()+"--"); 
		}
	;
	
argument_list : argument_list COMMA logic_expression
	    {
	    	$<s>$=new SymbolInfo();
	    	fprintf(logs,"Line at %d : argument_list->arguments COMMA logic_expression \n\n",line_count);
			fprintf(logs,"%s,%s\n\n",$<s>1->getName().c_str(),$<s>3->getName().c_str());
			
			tempArgList.push_back($<s>1);
			$<s>$->setName($<s>1->getName()+","+$<s>3->getName());
			$<s>$->setASMcode($<s>1->getASMcode()+$<s>3->getASMcode());
											
	    }
	    | logic_expression
	    {
			$<s>$=new SymbolInfo();
		  	fprintf(logs,"Line at %d :  argument_list->logic_expression  \n\n",line_count);
		  	fprintf(logs,"%s\n\n",$<s>1->getName().c_str()); 

		  	tempArgList.push_back($<s>1);
		  	$<s>$->setName($<s>1->getName());
		  	$<s>$->setASMcode($<s>1->getASMcode());
		 
	    }
	    	
	    ;









%%
int main(int argc,char *argv[])
{

	if((fp=fopen(argv[1],"r"))==NULL)
	{
		printf("Cannot Open Input File.\n");
		exit(1);
	}




	yyin=fp;
	yyparse();
	fclose(fp);
	fprintf(logs,"Total Line : %d \nTotal errors : %d  \n\n",line_count,error_count);
	fprintf(errors,"Total Line : %d \nTotal errors : %d  \n\n",line_count,error_count);
	
	fclose(errors);
	fclose(logs);
	
	
	return 0;
}

