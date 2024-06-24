#Módulo contendo as funções que retornam os dados dos operadores e das viagens
#No geral, vai receber uma planilha com os horários em horas e converter tudo isso para tempo corrido em minutos
#Mas precisamos que os horários de entrada/saida na planilha dos operadores estejam separados em colunas distintas e sem aqueles titulos
module Dados
    export dadosViagens,dadosOperadores, operador, viagem
    using DataFrames, XLSX, Dates
    #Declarando tipos compostos de dados para o desenvolvimento do método pode realizar
    #Struct do operador - Tomamos I_alm=3000=F_alm para garantir a validade da condição 1 em operadores_disp
    Base.@kwdef mutable struct operador
        cod::String #Identificação/código do operador
        HE::Float64 #Horário de entrada em minutos
        HS::Float64 #Horário de saída em minutos
        I_alm::Float64 = 3000 #Início do horário de almoço
        D_alm::Float64 #Duração do horário de almoço
        F_alm::Float64 = 3000 #Fim do horário de almoço
        Turno::Char #Caractere que indica o turno do operador -> M = Manhã, T=Tarde, N=Noite
        Alm::Bool = false #Flag que indica se o operador já almoçou ou não
        Min_viag::Int #Indica o número de viagens a serem realizadas antes do horário de almoço
        Nviag::Int = 0 #Número de viagens realizadas pelo  -> Variável usada para ver o horário de almoço
    end

    #Struct da viagem 
    Base.@kwdef mutable struct viagem
        numViag::Int #Numero/Id da viagem 
        HP::Float64 #Horário de partida em minutos
        HT::Float64 #Horário de término da viagem
        codOp::String=" " #Código do operador que está responsável pela viagem
    end

    #Funções para converter o tempo nos dados no formato que o método precisamos

    #Função que converte um horário em HH:MM:SS para minutos, pensando em tempo corrido
    #t0 -> horário de referencia, se t<t0 somamos 1440 minutos pois estaríamos no dia seguinte
    #Para as viagens t0 deve ser o horário da primeira viagem.
    #Para um funcionário, t0 vai ser o horário de entrada desse operador se t for o horário de saída dele.
    #se t for o horário de entrada, t0 é meia noite (00:00:00)
    function tempoEmMinutos(t,t0)
        t>=t0 ? minutos_totais=hour(t)*60+minute(t)+second(t)/60 : minutos_totais=hour(t)*60+minute(t)+second(t)/60+1440
        return minutos_totais
    end

    #Função que converte uma entrada do dataframe do tipo Time em um float64 representando o mesmo tempo em minutos
    function converterTempoSing(t,t0)
        resp=ismissing(t) ? missing : tempoEmMinutos(t,t0)
        return resp
    end

    #Função que converte o dataframe com entradas de tempo para um com entradas em minutos (float64)
    function converterTempo(dt,t0)
        m,n=size(dt) #Número de linhas e colunas do dataframe, respectivamente 
        #convertendo para minutos cada uma das colunas
        for j=1:n
            dt[!, j]=[converterTempoSing(dt[i,j],t0) for i=1:m]
        end
        return dt
    end

    #Função que converte uma entrada dos dados de string/DateTime para Time
    function converterParaTime(t)
        resp=t
        if !ismissing(resp)
            if typeof(resp)==String
                partes=split(resp,":")
                h=partes[1]; m=partes[2]
                if length(partes)==2
                    s="00"
                else
                    s=partes[3]
                end
                hora=parse(Int,h)
                if hora>=24
                    hora=24-hora;
                end
                resp=Time(hora,parse(Int,m),parse(Int,s))
            elseif typeof(t)!=Time
                resp=Time(t)
            end
        end
        return resp
    end

    #Função que converte todas as entradas que não são missing de um dataframe para Time (Sendo elas string/datetime)
    function converterDfParaTime(df)
        m,n=size(df);
        for i=1:m
            for j=1:n
                df[i,j]=converterParaTime(df[i,j])
            end
        end
    end

    #Função que lê a planilha das viagens e faz o pré-processamento -> opt será o nº da pagina da planilha
    #DuracaoViag será a duração de cada viagem em minutos, padronizamos tudo para 60 para tomar um limite superior
    #Retorna o vetor das viagens
    function dadosViagens(opt,duracaoViag=60)
        #Lendo a planilha das viagens
        dt=DataFrame(XLSX.readtable("Viagens-L1-2023.xlsx",opt))
        dt=dt[!,2:6] #Removendo a coluna do número da viagem
        m=nrow(dt) #Número de linhas do dataframe
        converterDfParaTime(dt) #Convertendo todas as entradas para o tipo Time 
        t0=minimum([first(skipmissing(dt[i,:])) for i=1:20]) #Pegando o horário da primeira viagem do dia para usar como t0
        converterTempo(dt,t0)#Convertendo os horários para minutos/tempo corrido
        #Criando o vetor das viagens
        partida=[first(skipmissing(dt[i,:])) for i=1:m] #Pegando os horários de partida de cada viagem
        termino=partida.+duracaoViag #Horário de termino de cada viagem
        viagens=[viagem(numViag=i,HP=partida[i],HT=termino[i]) for i=1:m] #Preenchendo o vetor das viagens
        viagens=sort(viagens,by=x->x.HP) #ordenando
        return viagens 
    end

    #Função que retorna a duração do horário de almoço do funcionário
    #Isso é feito vendo se a duração do expediente é correta (dos que tem processo trabalhista)
    #Só usamos a função quando 
    function getDAlm(dExped)
        if dExped==492 || dExped==540 || dExped==554
            D=60.
        else
            D=30.
        end
        return D
    end

    #Tratativa dos operadores -> Consideramos que todos os operadores estão disponíveis todos os dias
    #MinViagens -> Vetor cuja i-esima entrada é o número de viagens que o i-ésimo operador tem que fazer antes de poder almoçar
    #Vetor de operadores segue a ordem: Todos da escala semanal (1º), escala 4x2x6x4 2ª parte do vetor, e escala 4x2x4 a 3ª
    #Primeiros operadores adicionados são os da manhã, depois os da tarde e em seguida os da noite
    function dadosOperadores(minViagens)
        #Lendo as planilhas dos horários dos operadores e gravando como dataframe
        dts=[DataFrame(XLSX.readtable("Horários_Funcionarios.xlsx",i)) for i=1:3]

        #Convertendo cada dataframe para ter entradas do tipo Time
        for i=1:3
            converterDfParaTime(dts[i]) 
        end
        
        #Convertendo cada tempo para minutos
        dtmin=deepcopy(dts)
        for k=1:3
            m,n=size(dts[k])
            for i=1:m
                for j=1:n
                    #Colunas pares são relacionadas aos horários de saída
                    #No caso das impares (horario de entrada), t0 não importa
                    #Devemos mudar t0 constantemente para garantir a propriedade de tempo corrido desejada
                    if mod(j,2)==1
                        dtmin[k][i,j]=converterTempoSing(dts[k][i,j],Time(0,0,0))
                    else 
                        dtmin[k][i,j]=converterTempoSing(dts[k][i,j],dts[k][i,j-1])
                    end
                end
            end
        end
        
        #Alocando o vetor dos operadores e Preenchendo
        operadores=[];
        aux=0 #Indice auxiliar para ajudar a atribuir o minimo de viagens
        for i=1:3
            m,n=size(dtmin[i]) #Pegando as dimensões 
            partida=[collect(skipmissing(dtmin[i][:,j])) for j=1:2:n] #Obtendo os vetores com os horários de entrada
            saida=[collect(skipmissing(dtmin[i][:,j])) for j=2:2:n] #Obtendo os vetores com os horários de saída
            #Etiqueta da escala para formar o código
            escala=""
            if i==1
                escala="S"
            elseif i==2
                escala="4x2x6x4"
            else
                escala="4x2x4"
            end
            #Preenchendo por turno
            for j in 1:round(Int,n/2)
                m=length(partida[j])
                if j==1 #Da manhã
                    for k=1:m
                        D=getDAlm(saida[j][k]-partida[j][k])
                        op=operador(cod=string(k)*"-"*escala*"-M",HE=partida[j][k],HS=saida[j][k],Turno='M',D_alm=D,Min_viag=minViagens[aux+k])
                        push!(operadores,op)
                    end
                elseif j==2 #Da tarde
                    for k=1:m
                        D=getDAlm(saida[j][k]-partida[j][k])
                        op=operador(cod=string(k)*"-"*escala*"-T",HE=partida[j][k],HS=saida[j][k],Turno='T',D_alm=D,Min_viag=minViagens[aux+k])
                        push!(operadores,op)
                    end
                else #Noturno
                    for k=1:m
                        op=operador(cod=string(k)*"-"*escala*"-N",HE=partida[j][k],HS=saida[j][k],Turno='N',D_alm=30.,Min_viag=minViagens[aux+k])
                        push!(operadores,op)
                    end
                end
                aux+=m
            end
        end
        return operadores
    end
end 
