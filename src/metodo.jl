#Arquivo que contém o método heurístico proposto para a resolução do problema
#Seguimos a ideia de pegar o primeiro operador capaz de realizar a viagem
#Mas exigimos alguns critérios adicionais, se possível, dando preferência para:
#1. Um operador que já fez uma viagem
#2. Um operador que já fez o horário de almoço
#E, no caso de termos mais de um agente que se encaixa nessa categoria, escolhemos aquele cujo horário de sáida esteja mais próximo
#Tomamos isso seguindo a ideia intuitiva de tentar reduzir o tempo que ele ficaria parado.

#Função que recebe o horário de partida e término de uma viagem
#A partir disso, devolve um vetor contendo os indices dos operadores disponiveis para realizá-la
function operadores_disp(Hp,Ht,operadores,TultViag,te,ts,tv,maxViag)
    n=size(operadores,1); op_disp=[]
    for i=1:n
        #Para uma viagem, temos dois casos para considerar:
        #1 - O funcionário que irá realizá-la entrou no período noturno do dia anterior e ainda está no expediente.
        #2 - O funcionário que irá realizá-la é do turno da manhã, da tarde ou da noite do dia atual
        #o 1º Caso é mais provável nas primeiras viagens do dia
        #Separamos os critérios a serem considerados nesses dois casos

        #Se o operador for do noturno e se ele ainda está no expediente que se começou no dia anterior
        #Essa condição está para checar a alocação dos operadores nas primeiras viagens do dia
        if operadores[i].Turno=='N' && operadores[i].HS-ts-1440>Ht && operadores[i].HE+te>Ht && (TultViag[i]==0 || Hp>TultViag[i]+tv)
            #Aqui, como o intervalo de tempo entre o começo da última viagem e o começo da primeira é de mais de 4 horas
            #Assumimos que o operador nesse caso já deve ter almoçado e portanto a lógica correspondente ao hor. almoço não se aplica
            push!(op_disp,i)
        else #Caso contrário, verificamos os critérios padrão
            #Checando condições para determinar a inelegibilidade do operador para a i-esima viagem
            Tu=TultViag[i]
            cond_HorarioEntrada=false; cond_HorarioIntervalo=false; cond_Almoco=false; cond_max=false; cond_ja_esta_em_viag=false

            #1 - Checamos se o Operador terminou o seu horário de almoço quando a viagem for considerada
            #Atualizamos caso seja necessário
            if operadores[i].F_alm<Hp
                operadores[i].Alm=true #O operador já almoçou e poderia se encarregar dessa viagem
            end

            #1.1 - Checamos se o operador já bateu o máximo de viagens
            if operadores[i].Nviag==maxViag
                cond_max=true
            end

            #2 - Checa se o expediente do operador termina antes da viagem começar
            cond_HorarioEntrada=operadores[i].HE > Hp
        
            #3 - Tempo entre a entrada\saida do operador e o inicio\termino da viagem
            cond_HorarioIntervalo=operadores[i].HE+te > Hp || operadores[i].HS-ts < Ht

            #4 - Horário de almoço - Deve ser feito obrigatoriamente pelo operador após um certo numero de viagens
            #Checamos se o operador não realizou o horário de almoço
            if !operadores[i].Alm
                #Checamos se ele fez o numero necessário de viagens
                if operadores[i].Min_viag==operadores[i].Nviag
                    #Se sim, ele irá realizar o horário de almoço agora
                    operadores[i].I_alm=Tu
                    operadores[i].F_alm=Tu+operadores[i].D_alm
                    #Verificando se há conflito de horário -> Viagem começa dentro do horário em que o operador está almoçando
                    if Hp <= operadores[i].F_alm
                        cond_Almoco=true #Horário de almoço vai interferir na decisão, operador não pode pegar a viagem
                    end
                end
            end

            #5 - Checamos se o operador, que acabou de chegar de uma viagem, está dentro do tempo adicional de locomoção
            cond_intervalo=TultViag[i]!=0 && Hp<TultViag[i]+tv

            #6 - Checamos se o operador já se encontra em uma viagem
            cond_ja_esta_em_viag=TultViag[i]!=0 && TultViag[i]>Hp

            #Checamos: nenhuma dessas condições é válida => O operador é aceito
            if !(cond_max || cond_HorarioEntrada || cond_HorarioIntervalo || cond_Almoco || cond_intervalo || cond_ja_esta_em_viag)
                push!(op_disp,i)
            end
        end
    end
    return op_disp
end

#Retorna o indice do operador que possui o menor horário de saída dentro do conjunto de indices informado
function selectOperador(operadores,ind)
    resp=0; min=9999
    for i in ind
        if min>operadores[i].HS
            min=operadores[i].HS; resp=i
        end
    end
    return resp
end

#Função que aplica a metodologia da heurística
#te,ts,tv -> Intervalos de tempo relacionados entrada/saida/entre viagens de um operador. Dado em minutos
#nOp -> número de operadores
function resolveFP(operadores,viagens,te,ts,tv,maxViag,TultViag=[0. for i=1:length(operadores)])
    #Iterando para cada viagem e achando o operador para realizá-la
    nOp=length(operadores); nV=length(viagens)
    for i=1:nV
        #Obtendo o conjunto dos indices dos operadores elegíveis para a i-esima viagem
        op_disp=operadores_disp(viagens[i].HP,viagens[i].HT,operadores,TultViag,te,ts,tv,maxViag)
        #Definindo o indice do operador escolhido
        indEscolha=0
        #Separando os que já fizeram ao menos uma viagem
        indRealizViag=[]
        for j in op_disp
            if operadores[j].Nviag>=1
                push!(indRealizViag,j) 
            end
        end
        #Caso esse conjunto seja vazio, tomamos o operador dentro do conjunto cujo horário de saída seja o menor
        if size(indRealizViag,1)==0
            indEscolha=selectOperador(operadores,op_disp)
        else #Se não, tentamos filtrar mais um pouco escolhendo operadores que já tenham almoçado
            indRealizViag_e_Alm=[]
            for j in indRealizViag
                if operadores[j].Alm==true
                    push!(indRealizViag_e_Alm,j)
                end
            end
            #Se esse conjunto for vazio, apenas tomamos um operador aleatório que tenha realizado viagem
            if size(indRealizViag_e_Alm,1)==0
                indEscolha=selectOperador(operadores,indRealizViag)
            else #Caso contrário, selecionamos um operador aleatoriamente nesse conjunto
                indEscolha=selectOperador(operadores,indRealizViag_e_Alm)
            end
        end
        viagens[i].codOp=operadores[indEscolha].cod; TultViag[indEscolha]=viagens[i].HT; 
        #Vendo se o operador escolhido nao foi do expediente anterior, nesse caso nao atualizamos o nViag
        if !(operadores[indEscolha].Turno=='N' && operadores[indEscolha].HS-ts-1440>viagens[i].HT)
            operadores[indEscolha].Nviag+=1; 
        end
    end
end